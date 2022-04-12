{ config, lib, pkgs, modulesPath, ... }:

{

  imports = [
    "${
      fetchTarball
      "https://github.com/NixOS/nixos-hardware/archive/feceb4d24f582817d8f6e737cd40af9e162dee05.tar.gz"
    }/raspberry-pi/4"
  ];

  hardware.raspberry-pi."4".fkms-3d.enable = true;

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

    "/mnt/usb" = {
      device = "/mnt/nfs";
      options = [ "bind" ];
    };
  };

  swapDevices = [ ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;
}
