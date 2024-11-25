{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub.device = "/dev/sda";
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
  # TODO get this automount volume working
  #  fileSystems."/mnt/volume-fsn1-1" = {
  #    device = "/dev/disk/by-id/scsi-0HC_Volme-30638498";
  #  };
}
