# Configurations that I tend to only use for work
{ pkgs, ... }: {

  homebrew.brews = [
    "rbenv"
    "predatorray/brew/kubectl-tmux-exec"
    "kwok"
  ];

  homebrew.casks = [
    "docker"
    "sdm"
    "viscosity"
  ];

  homebrew.taps = [
    "predatorray/brew"
  ];

}
