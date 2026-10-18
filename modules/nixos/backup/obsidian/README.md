# obsidian

```nix
modules.backup.obsidian = {
  enable = true;
  rcloneConfigFile = config.age.secrets."rclone.conf".path;
  history.enable = true;
  missingAttachmentsHealthcheck = "https://healthchecks.../ping/<uuid>";
  staleMirrorHealthcheck = "https://healthchecks.../ping/<uuid>";
};
```

Keeps a read-only mirror of the Obsidian vault on the host and backs it up. Charlie runs it. The laptops run Obsidian desktop and are the only places the vault is edited.

## How it fits together

| Unit | Schedule | What it does |
| ---- | -------- | ------------ |
| `obsidian-sync` | always running | `ob sync --continuous` from `obsidian-headless` (nixpkgs-unstable) mirrors the vault from Obsidian Sync into `/var/lib/obsidian/repo/Get-Started`. |
| `obsidian-history` | hourly at :55 | Commits the vault's notes and settings to the bare repo `/var/lib/obsidian/history.git`, then pings the missing-attachments healthcheck. |
| `restic-backups-obsidian` | hourly | Backs up `repo` and `history.git` to `rclone:b2:iifu8Noi-backups/restic/obsidian` and pings its own healthcheck. |
| `obsidian-sync-check` | every 10 minutes | Pings `/fail` on the stale-mirror healthcheck when `ob` hasn't synced for 15 minutes. |

Everything runs as the `obsidian` system user. `jdheyburn` is in the `obsidian` group.

### Sync

The sync runs in `mirror-remote` mode: it only downloads, reverts any local change and deletes local-only files. Nothing on the host can change the vault, so editing or restoring files in `repo` does nothing useful. Restore into a laptop vault and let Obsidian Sync carry it.

Every config category and attachment type is synced, so restic and git see the whole vault, including `.obsidian/`.

`ob` logs to `/var/lib/obsidian/.config/obsidian-headless/sync/<vault-id>/sync.log` and to the journal. The file is append-only and never rotated; it grows by about 115 KB a day.

### History

`history.git` holds every `.md`, `.canvas` and `.base` file, plus `.obsidian/*.json` (except `workspace*.json`) and each community plugin's `manifest.json` and `data.json`. The rules are in `vault-exclude`. Plugin `data.json` files can hold API tokens; the repo never leaves the host and its restic backup.

Attachments stay out of git. Each commit carries `attachments.manifest` instead, one tab-separated `sha256 size path` line per attachment, so a commit records which attachments existed and their content. The vault itself is never written to.

The first 127 commits were backfilled from restic by `obsidian-backfill` (`backfill.py`), one per snapshot that changed something, dated to the snapshot. It only runs against a missing `history.git`.

### Alerts

The missing-attachments check finds every attachment a note embeds or links (`![[x.png]]`, `[x](x.pdf)`) and fails when one doesn't resolve the way Obsidian would resolve it. The failure body lists `note: target` pairs. A target listed in `/var/lib/obsidian/ignored-missing-attachments`, one per line, doesn't alert. The file lives on the host because the names come from the vault and this repo is public; the nine in it on charlie were lost before restic backups began in December 2024. Edit it as root and keep it readable by the `obsidian` group. A missing file means nothing is ignored.

The stale-mirror check reads the end of `sync.log`. `ob` logs "Fully synced" every 30 seconds while connected and "Downloaded <path>" while catching up, and neither while disconnected. The check fails when the newest of those lines is over 15 minutes old. `ob sync-status` only reports config, so the log is the only signal.

Healthchecks schedules:

| Check | Cron | Grace |
| ----- | ---- | ----- |
| Missing attachments | `55 * * * *` | 15 minutes |
| Stale mirror | `*/10 * * * *` | 10 minutes |

## Setting up a host

`ob login` and `ob sync-setup` are interactive and store credentials under `/var/lib/obsidian/.config/obsidian-headless/`, outside the vault. After the first deploy:

```sh
sudo systemctl stop obsidian-sync
sudo -u obsidian -H ob login
sudo -u obsidian -H ob sync-list-remote
sudo -u obsidian -H ob sync-setup --vault Get-Started --path /var/lib/obsidian/repo/Get-Started --device-name charlie
sudo systemctl start obsidian-sync
```

`sync-setup` defaults to bidirectional sync. Keep the service stopped until it's done: starting it runs `ExecStartPre`, which sets `mirror-remote` before anything syncs. Check with `ob sync-status --path /var/lib/obsidian/repo/Get-Started`.

To backfill history, leave `history.enable` off, stop `restic-backups-obsidian.timer`, run `sudo obsidian-backfill`, then start the timer again. It writes a report of files that some snapshot held and the newest doesn't to `/var/lib/obsidian/backfill-lost-files.tsv`. Then enable `history.enable`, and add any targets from the first run's failures that can't be restored to the ignore file.

## Restoring

A note or setting, from git:

```sh
git clone charlie-no-tmux:/var/lib/obsidian/history.git /tmp/vault-history
git -C /tmp/vault-history log --oneline -- 'notes/Some note.md'
git -C /tmp/vault-history show <commit>:'notes/Some note.md'
```

The plain `charlie` SSH host starts tmux, which breaks git over SSH.

An attachment, from restic. `attachments.manifest` in git says when it last existed:

```sh
git -C /tmp/vault-history log -1 --format='%h %cI' -S 'attachments/x.png' -- attachments.manifest
sudo restic-obsidian snapshots
sudo restic-obsidian restore <snapshot> --target /tmp/restore \
  --include '/var/lib/obsidian/repo/Get-Started/notes/attachments/x.png'
```

Copy the restored file into a laptop vault.

## Tests

```sh
just test
```

Includes the pytest suites for `vault.py`, `history.py`, `backfill.py` and `mirror.py`. The scripts use only the standard library and run under the host's `python3`.
