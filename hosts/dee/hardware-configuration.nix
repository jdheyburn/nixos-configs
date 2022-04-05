{ config, lib, pkgs, modulesPath, ... }:

{

  imports = [
    "${
      fetchTarball
      "https://github.com/NixOS/nixos-hardware/archive/feceb4d24f582817d8f6e737cd40af9e162dee05.tar.gz"
    }/raspberry-pi/4"
  ];
  #  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  hardware.raspberry-pi."4".fkms-3d.enable = true;

  #boot.loader.raspberryPi = {
  #  enable = true;
  #  version = 4;
  #};

  # File systems configuration for using the installer's partition layout
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    "/mnt/nfs" = {
      device = "/dev/disk/by-uuid/D28E73C08E739BA3";
      fsType = "ntfs";
    };
  };

  swapDevices = [ ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;

}
