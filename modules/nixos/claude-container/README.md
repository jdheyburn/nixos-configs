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

Runs Claude Code Remote Control servers in a NixOS container, one per repo, so Claude can be started and steered from claude.ai/code or the Claude app with no laptop awake. charlie runs it. The design is in `docs/superpowers/specs/2026-10-25-claude-remote-control-design.md` (local, gitignored).

## How it fits together

| Layer | What it does |
| ----- | ------------ |
| Container `claude` | systemd-nspawn with its own network namespace, NATed out of `externalInterface`. Host firewall rules drop everything from `ve-claude` to the host and forward nothing to private ranges, the tailnet or `169.254.0.0/16`. |
| `claude-remote-control.service` (inside) | Runs `herdr server` as the `claude` user with systemd hardening. Before start it pre-trusts `~/code/<name>` in `~/.claude.json`. After start it opens one Herdr workspace per server, which clones the repo if it is missing (the container has no network until boot finishes) and then loops `claude remote-control --spawn worktree` from its own worktree at `~/rc/<name>`, so a restart resumes the sessions it was serving. |
| Managed settings | `/etc/claude-code/managed-settings.d/claude-remote-control.json`: sandbox on with no unsandboxed retries, a domain allowlist, no unix sockets, only the Claude Docs and Todoist connectors, and deny rules for `gh pr merge` and pushes to `main`. `/etc/claude-code/CLAUDE.md` tells Claude it can't use Nix or the vault and must only open PRs. |
| home-manager | The `claude` user gets `home/profiles/agent`, the Claude Code and Herdr config shared with the desktop. |

Sessions appear in claude.ai/code as `charlie-nixos-configs` and `charlie-scratch`.

## Setting up

1. Create a fine-grained GitHub token for `jdheyburn/nixos-configs` and `jdheyburn/scratch`: contents, pull requests and issues read-write, metadata read-only, no workflows. Save it with `agenix -e secrets/claude-gh-token.age` as one line, `GH_TOKEN=<token>`.
2. On GitHub, add a ruleset to `main` in nixos-configs that blocks direct pushes and requires a PR, with an empty bypass list. scratch is private on the Free plan, where rulesets don't enforce.
3. Deploy, then log in from the host:

   ```sh
   sudo nixos-container root-login claude
   sudo -u claude -i claude auth login        # choose the claude.ai option
   systemctl restart claude-remote-control && exit
   ```

4. In a session: `/config` and turn on "Push when actions required" and "Push when Claude decides".
5. If `/mcp` shows Todoist needs authorizing: `sudo -u claude -i claude mcp login "claude.ai Todoist"` inside the container, then open the link on your phone.
6. Optional: turn on "Require trusted devices" in claude.ai account settings.

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

## Accepted risks

- Claude could merge its own PRs. The token is Joe's, and GitHub doesn't let an author approve their own PR, so a required-approval ruleset would lock Joe out. The `gh pr merge` deny and the managed CLAUDE.md are the only guards.
- scratch has no server-side protection on `main`.
- `GH_TOKEN` is visible to sandboxed commands, since `gh` needs it. The domain allowlist and the token's scope bound it.

## Resetting

```sh
sudo nixos-container destroy claude   # then redeploy and log in again
```
