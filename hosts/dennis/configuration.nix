{ config, pkgs, ... }:

{

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
  ## Backups
  ###############################################################################

  age.secrets."restic-dennis-password".file =
    ../../secrets/restic-dennis-password.age;

  services.restic.backups = {

    small-files = {
      repository = "/mnt/nfs/restic/dennis";
      passwordFile = config.age.secrets."restic-dennis-password".path;
      # TODO change these to be configured if the service is enabled
      paths = [ "/var/lib/grafana/data" "/var/lib/prometheus2/data" ];
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 3"
      ];
      timerConfig = { OnCalendar = "*-*-* 02:00:00"; };
    };
  };

  ###############################################################################
  ## Modules
  ###############################################################################

  modules.monitoring.enable = true;

  modules.prometheusStack.enable = true;

  services.qemuGuest.enable = true;

  # Keeps crapping out for some reason: https://askubuntu.com/questions/1018576/what-does-networkmanager-wait-online-service-do
  systemd.services."NetworkManager-wait-online".enable = false;

}
