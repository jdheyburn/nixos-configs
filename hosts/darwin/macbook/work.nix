# Configurations that I tend to only use for work
{ pkgs, ... }: {

  homebrew.brews = [
    # TODO make this trusted
    "datadog-labs/pack/pup"
    "rbenv"
    # TODO make this trusted
    "predatorray/brew/kubectl-tmux-exec"
    "kwok"
  ];

  homebrew.casks = [
    "claude"
    "docker"
    "google-drive"
    "sdm"
  ];

  homebrew.taps = [
    "datadog-labs/pack"
    "predatorray/brew"
  ];
}
