{ config, lib, pkgs, modulesPath, ... }:

{

  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;

  boot.loader.raspberryPi = {
    enable = true;
    version = 4;
  };

  # File systems configuration for using the installer's partition layout
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };

    # "/mnt/usb" = {
    #   device = "/dev/disk/by-uuid/D28E73C08E739BA3";
    #   fsType = "ntfs";
    # };
  };

  swapDevices = [ ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;

}
