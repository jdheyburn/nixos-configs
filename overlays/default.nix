inputs:
let inherit inputs;
in final: prev: {

  # to allow for creation of superuser, and use of EMAIL_HOST_PASSWORD_FILE variable
  healthchecks = prev.callPackage ./healthchecks { };

  # to mitigate this issue https://github.com/NixOS/nixpkgs/issues/187904
  plex = prev.callPackage ./plex { };

  # Disabled since AGH has since been updated
  # adguardhome = prev.callPackage ./adguardhome { };

  # adguardhome = prev.adguardhome.overrideAttrs (finalAttrs: previousAttrs: {
  #     version = "0.107.10";
  # });

  # below doesn't work, only above does
  # healthchecks = prev.healthchecks.overrideAttrs (finalAttrs: previousAttrs: {
  #     localSettings = prev.writeText "local_settings.py" ''
  #       import os
  #       STATIC_ROOT = os.getenv("STATIC_ROOT")
  #       SECRET_KEY_FILE = os.getenv("SECRET_KEY_FILE")
  #       if SECRET_KEY_FILE:
  #           with open(SECRET_KEY_FILE, "r") as file:
  #               SECRET_KEY = file.readline()

  #       EMAIL_HOST_PASSWORD_FILE = os.getenv("EMAIL_HOST_PASSWORD_FILE")
  #       if EMAIL_HOST_PASSWORD_FILE:
  #           with open(EMAIL_HOST_PASSWORD_FILE, "r") as file:
  #               EMAIL_HOST_PASSWORD = file.readline()
  #     '';
  #   });
}
