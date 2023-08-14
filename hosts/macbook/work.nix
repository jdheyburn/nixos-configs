{ pkgs, ... }: {

  homebrew.brews = [
    "rbenv"
    "predatorray/brew/kubectl-tmux-exec"
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