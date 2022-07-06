# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules =
    [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];

  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.kernelParams = [ "console=tty1" "console=ttyS0,115200" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/278a6de8-dadb-488f-ad09-477c43ceddb3";
    fsType = "ext4";
  };

    fileSystems."/mnt/nfs" = {
      device = "192.168.1.10:/mnt/nfs";
      fsType = "nfs";
      options = [ "x-systemd.automount" "noauto" ];
    };

  swapDevices = [ ];

  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
