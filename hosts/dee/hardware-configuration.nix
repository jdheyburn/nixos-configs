{ config, lib, pkgs, modulesPath, ... }:

{
  hardware.raspberry-pi."4".fkms-3d.enable = true;
  hardware.raspberry-pi."4".dwc2.enable = false;

  boot.kernelPackages = pkgs.linuxPackages_rpi4;
  boot.kernelParams = [
    "usb-storage.quirks=174c:1156:u"
    "8250.nr_uarts=1"
    "console=ttyAMA0,115200"
    "console=tty1"
    "cma=128M"
  ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "usbhid" "uas" "usb_storage" "vc4" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.initrd.supportedFilesystems = [ "zfs" ];
  boot.supportedFilesystems = [ "zfs" ];

  boot.consoleLogLevel = 7;

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

  #fileSystems."/mnt/nfs" = {
  #  device = "/dev/disk/by-uuid/242E77B52E777F1C";
  #  fsType = "ntfs";
  #  options = [ "nofail" ];
  #};

  fileSystems."/mnt/nfs" = {
    device = "/dev/disk/by-uuid/5bc9d4ef-9379-4381-bfbd-dfe63a0575ea";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  fileSystems."/mnt/usb" = {
    device = "/mnt/nfs";
    options = [ "bind" ];
  };

  swapDevices = [ ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  powerManagement.powertop.enable = true;
}

