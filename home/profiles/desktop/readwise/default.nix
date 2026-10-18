{ lib, pkgs, inputs, ... }:
let
  skillsDir = "${inputs.readwise-skills}/skills";
in
{
  # `readwise` CLI. Log in once with `readwise login`; credentials live in
  # ~/.readwise-cli.json, outside the store.
  home.packages = [ (pkgs.callPackage ./package.nix { }) ];

  # Every skill in readwiseio/readwise-skills, by directory name. The repo is
  # also a Claude Code plugin, but that would add a second copy of the
  # Readwise MCP server next to the claude.ai connector, so only the skills
  # are linked here.
  programs.claude-code.skills = lib.mapAttrs
    (name: _: "${skillsDir}/${name}")
    (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir));
}
