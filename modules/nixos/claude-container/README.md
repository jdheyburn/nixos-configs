# claude-container

```nix
age.secrets."claude-gh-token" = {
  file = myUtils.secrets.file "claude-gh-token";
  path = "/run/claude-secrets/gh-token";
  symlink = false;
  owner = "claude";
  group = "claude";
  mode = "0400";
};
modules.claude-container = {
  enable = true;
  externalInterface = "eth0";
  githubTokenFile = config.age.secrets."claude-gh-token".path;
  service.servers = {
    nixos-configs.repo = "jdheyburn/nixos-configs";
    scratch.repo = "jdheyburn/scratch";
  };
};
```

Runs Claude Code Remote Control servers in a NixOS container, one per repo, so Claude can be started and steered from claude.ai/code or the Claude app with no laptop awake. charlie runs it.

## How it fits together

| Layer | What it does |
| ----- | ------------ |
| Container `claude` | systemd-nspawn with its own network namespace, NATed out of `externalInterface`. Host firewall rules drop everything from `ve-claude` to the host and forward nothing to private ranges, the tailnet or `169.254.0.0/16`. |
| `claude-remote-control.service` (inside) | Runs `herdr server` as the `claude` user with systemd hardening. Before start it pre-trusts `~/code/<name>` in `~/.claude.json`. After start it opens one Herdr workspace per server, which clones the repo if it is missing (the container has no network until boot finishes) and then loops `claude remote-control --spawn worktree` from its own worktree at `~/rc/<name>`, so a restart resumes the sessions it was serving. |
| Managed settings | `/etc/claude-code/managed-settings.d/claude-remote-control.json`: sandbox on with no unsandboxed retries, a domain allowlist, no unix sockets, only the Claude Docs and Todoist connectors, and deny rules for `gh pr merge` and pushes to `main`. `/etc/claude-code/CLAUDE.md` tells Claude it can't use Nix or the vault and must only open PRs. |
| `claude-remote-control-prune-worktrees.timer` (inside) | Daily. Removes session worktrees in `~/code/<name>/.claude/worktrees/` whose session has ended and that are untouched for 7 days, with no local changes and every commit on origin, and deletes their branches. |
| home-manager | The `claude` user gets `home/profiles/agent`, the Claude Code and Herdr config shared with the desktop. |

Sessions appear in claude.ai/code as `charlie-nixos-configs` and `charlie-scratch`.

## Setting up

1. Create a fine-grained GitHub token for `jdheyburn/nixos-configs` and `jdheyburn/scratch`: contents, pull requests and issues read-write, metadata read-only, no workflows. Save it with `agenix -e secrets/claude-gh-token.age` as one line, `GH_TOKEN=<token>`.
2. Deploy, then log in from the host:

   ```sh
   sudo nixos-container root-login claude
   sudo -u claude -i claude auth login        # choose the claude.ai option
   systemctl restart claude-remote-control && exit
   ```

3. Download the plugins once. `enabledPlugins` only switches on plugins whose files are already downloaded, and a fresh container has none. Inside the container:

   ```sh
   sudo -u claude -i claude plugin install superpowers@claude-plugins-official
   sudo -u claude -i claude plugin install obsidian@obsidian-skills
   ```

   Each fails at the end with `EROFS` because `settings.json` is read-only; the plugin is downloaded by then and loads in new sessions.
4. Turn on push notifications. `/config` only exists in a terminal session, so start one inside the container with `sudo -u claude -i bash -c 'cd ~/rc/scratch && claude'`, run `/config`, turn on "Push when actions required" and "Push when Claude decides", then `/exit`. The settings belong to the account, so once is enough.
5. Optional: turn on "Require trusted devices" in claude.ai account settings.

Connectors need no setup here: their logins live with the claude.ai account, and the managed allowlist lets through only Claude Docs and Todoist.

## Adding a repo

1. Add it to `service.servers`, with any tools its sessions need in `service.extraPackages`.
2. Add the repo to the GitHub token's repository access in GitHub settings. The token value doesn't change, so the secret stays as it is. Without this, a public repo still clones but every push fails.
3. Deploy. The loop clones the repo and its Herdr workspace starts a new server.

A fork works too: the loop sets `remote.origin.gh-resolved`, so `gh` opens PRs against the fork and not its upstream.

## Attaching

Some permission prompts only render in a terminal. To answer one:

```sh
ssh charlie
sudo nixos-container root-login claude
sudo -u claude -i herdr
```

The container's Herdr prefix is `ctrl+b`, so it still works from inside a pane of the laptop's Herdr. `ctrl+b q` detaches and leaves the servers running. Then `exit` out of the container shell. Closing the terminal instead can leave the login's `su` as a zombie inside the container, and the next container stop then hangs on it. If a stop or switch fails with `Machine 'claude' already exists`:

```sh
sudo machinectl terminate claude
sudo systemctl reset-failed container@claude && sudo systemctl start container@claude
```

The host can't SSH into the container: the firewall drops every packet from `ve-claude` to the host, replies included.

## Rotating the GitHub token

The servers read `GH_TOKEN` once, when the service starts. A new token in `secrets/claude-gh-token.age` reaches the file on deploy but not the running servers, so pushes fail with 401 until the service restarts:

```sh
agenix -e secrets/claude-gh-token.age    # on the laptop, then commit, push and deploy
sudo nixos-container run claude -- systemctl restart claude-remote-control
```

Open sessions resume after the restart.

## Accepted risks

- Claude could merge its own PRs. The token is Joe's, and GitHub doesn't let an author approve their own PR, so a required-approval ruleset would lock Joe out. The `gh pr merge` deny and the managed CLAUDE.md are the only guards.
- Neither repo has a ruleset on `main`. scratch is private on GitHub Free, where rulesets aren't enforced, and nixos-configs has none by choice. The push-to-`main` deny rules and the managed CLAUDE.md are the only guards.
- `GH_TOKEN` is visible to sandboxed commands, since `gh` needs it. The domain allowlist and the token's scope bound it.

## Resetting

```sh
sudo nixos-container destroy claude   # then redeploy and log in again
```
