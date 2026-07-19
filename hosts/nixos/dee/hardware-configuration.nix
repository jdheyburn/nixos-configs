{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  # boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.initrd.availableKernelModules = [ "pcie-brcmstb" "reset-raspberrypi" ];
  hardware.deviceTree.enable = true;
  hardware.deviceTree.filter = "bcm2711-rpi-*.dtb";

  hardware.i2c.enable = true;
  boot.kernelModules = [ "i2c-dev" "i2c-bcm2835" ];
  boot.kernelParams = [ "dtparam=i2c_arm_baudrate=10000" ];

  # systemd.services.argon-fan-off = {
  #   description = "Force Argon ONE fan off at boot";
  #   after = [ "multi-user.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.i2c-tools}/bin/i2cset -y 1 0x1a 0x00";
  #   };
  # };

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "ext4";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
