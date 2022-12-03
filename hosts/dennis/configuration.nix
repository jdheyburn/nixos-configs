{ config, lib, pkgs, ... }:
let

  backupPaths = with lib;
    (optional config.services.grafana.enable "/var/lib/grafana/data")
    ++ (optional config.services.prometheus.enable "/var/lib/prometheus2/data")
    ++ (optional config.services.loki.enable "/var/lib/loki");

in {

  imports = [ ./hardware-configuration.nix ];

  ###############################################################################
  ## General
  ###############################################################################

  networking.hostName = "dennis";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.ens18.useDHCP = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  ###############################################################################
  ## Modules
  ###############################################################################

  age.secrets."restic-small-files-password".file =
    ../../secrets/restic-small-files-password.age;

  modules.backupSF = {
    enable = true;
    passwordFile = config.age.secrets."restic-small-files-password".path;
    paths = backupPaths;
    healthcheck =
      "https://healthchecks.svc.joannet.casa/ping/b4f0796c-b0c6-48d3-926e-2f7fdebc4e1b";
  };

  modules.caddy.enable = true;

  modules.dashy.enable = true;

  modules.monitoring.enable = true;

  modules.prometheusStack.enable = true;
  modules.prometheusStack.victoriametrics.enable = true;

  services.qemuGuest.enable = true;

  # Keeps crapping out for some reason: https://askubuntu.com/questions/1018576/what-does-networkmanager-wait-online-service-do
  systemd.services."NetworkManager-wait-online".enable = false;
}

