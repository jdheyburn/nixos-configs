
{ config, pkgs, lib, ... }:

#with lib;

{

  imports = [ ./small-files.nix ./usb.nix];

}
