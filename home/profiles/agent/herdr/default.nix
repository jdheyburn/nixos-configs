{ config, pkgs, system, inputs, ... }:
let
  toml = pkgs.formats.toml { };

  claudeHook = ".claude/hooks/herdr-agent-state.sh";
in
{
  home.packages = [ inputs.herdr.packages.${system}.default ];

  # Read-only store symlink, so herdr's settings UI (prefix+s) and onboarding
  # can't write here. Change settings in this file instead. Every option is
  # listed by `herdr --default-config`; apply with `herdr server reload-config`.
  #
  # No theme set: herdr defaults to "catppuccin" (mocha). It has no macchiato
  # variant and catppuccin/nix has no herdr module.
  xdg.configFile."herdr/config.toml".source = toml.generate "herdr-config.toml" {
    onboarding = false;

    ui.toast.delivery = "herdr";

    # Matches the tmux prefix in home/common/tmux.
    keys.prefix = "ctrl+space";
  };

  # Claude integration for native session restore. Replaces
  # `herdr integration install claude`, which can't register the hook because
  # settings.json is a read-only store symlink. The script comes from the herdr
  # flake input so it tracks the pinned binary; the hook entry mirrors
  # src/integration/claude_settings.rs. The script exits early outside a pane.
  home.file.${claudeHook} = {
    source = "${inputs.herdr}/src/integration/assets/claude/herdr-agent-state.sh";
    executable = true;
  };

  # Teaches Claude to drive herdr from inside a pane (splits, reading output,
  # waiting on other agents). Same release as the pinned binary.
  programs.claude-code.skills.herdr = "${inputs.herdr}/skills/herdr";

  programs.claude-code.settings.hooks.SessionStart = [
    {
      matcher = "^(startup|resume|clear|compact|fork)$";
      hooks = [
        {
          type = "command";
          command = "bash '${config.home.homeDirectory}/${claudeHook}' session";
          timeout = 10;
        }
      ];
    }
  ];
}
