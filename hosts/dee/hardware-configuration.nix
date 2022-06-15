{ config, lib, pkgs, modulesPath, ... }:

{
  # TODO nix flake nixos-hardware instead
  imports = [
    "${
      fetchTarball {
        url =
          "https://github.com/NixOS/nixos-hardware/archive/feceb4d24f582817d8f6e737cd40af9e162dee05.tar.gz";
        sha256 = "1q92jq6xf5b1pshai9j72cj17r0ah3fhrx669h3vc58rj7xvgiw7";
      }
    }/raspberry-pi/4"
  ];

  hardware.raspberry-pi."4".fkms-3d.enable = true;

  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" "uas" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.initrd.supportedFilesystems = [ "zfs" ];
  boot.supportedFilesystems = [ "zfs" ];

  fileSystems."/" = {
    device = "rpool/root/nixos";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "rpool/home";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/D36D-B744";
    fsType = "vfat";
  };

  fileSystems."/mnt/nfs" = {
    device = "/dev/disk/by-uuid/D28E73C08E739BA3";
    fsType = "ntfs";
    options = [ "nofail" ];
  };

  fileSystems."/mnt/usb" = {
    device = "/mnt/nfs";
    options = [ "bind" ];
  };

  swapDevices = [ ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;
}

