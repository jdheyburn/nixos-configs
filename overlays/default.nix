inputs:
let
    inherit inputs;
in
final: prev: {

    healthchecks = prev.callPackage ./healthchecks { };
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
