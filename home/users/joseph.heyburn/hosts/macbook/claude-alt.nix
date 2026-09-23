# A second Claude Code install, logged into another work account, that
# shares the primary's config. `claude-alt` sets CLAUDE_CONFIG_DIR, so login
# (Keychain) and .claude.json stay per-account while everything else links
# back into the primary config dir.
{ config, ... }:
let
  claudeHome = config.programs.claude-code.configDir;
  altDir = ".claude-alt";
  altHome = "${config.home.homeDirectory}/${altDir}";

  # Out-of-store links to the live primary paths, not the module's store
  # paths: reading config.home.file here would recurse, and linking the whole
  # skills/projects dirs also picks up anything added imperatively.
  #
  # plugins/ is left out on purpose. enabledPlugins lives in the shared
  # settings.json, so the alt install fetches its own copy instead of two
  # instances writing one cache.
  shared = [
    "settings.json"
    "CLAUDE.md"
    "statusline-command.sh"
    "skills"
    # Transcripts and per-project auto-memory, so both accounts resume and
    # remember the same work.
    "projects"
  ];
in
{
  home.file = builtins.listToAttrs (map
    (name: {
      name = "${altDir}/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${claudeHome}/${name}";
    })
    shared);

  # settings.json is shared, so the plugins read rule has to cover both dirs.
  programs.claude-code.settings.permissions.allow = [
    "Read(/${altHome}/plugins/**)"
  ];

  programs.zsh.shellAliases.claude-alt = "CLAUDE_CONFIG_DIR=${altHome} claude";
}
