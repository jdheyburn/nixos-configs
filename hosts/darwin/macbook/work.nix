# Configurations that I tend to only use for work
{ pkgs, ... }: {

  homebrew.brews = [
    "datadog-labs/pack/pup"
    "rbenv"
    "predatorray/brew/kubectl-tmux-exec"
    "kwok"
  ];

  homebrew.casks = [
    # "docker"
    "sdm"
    "viscosity"
  ];

  homebrew.taps = [
    "datadog-labs/pack"
    "predatorray/brew"
  ];
}
