{ writeText, healthchecks }:

let
  # From https://github.com/linuxserver/docker-healthchecks/blob/master/root/etc/cont-init.d/30-config#L116
  createSuperuser = writeText "create_superuser.py" ''
    from django.contrib.auth.models import User;
    from hc.accounts.views import _make_user;
    import os

    SUPERUSER_EMAIL = os.getenv("SUPERUSER_EMAIL")
    SUPERUSER_PASSWORD_FILE = os.getenv("SUPERUSER_PASSWORD_FILE")
    if SUPERUSER_PASSWORD_FILE:
        with open(SUPERUSER_PASSWORD_FILE, "r") as file:
            SUPERUSER_PASSWORD = file.readline()
    if SUPERUSER_EMAIL and SUPERUSER_PASSWORD:
        if User.objects.filter(email=SUPERUSER_EMAIL).count() == 0:
            user = _make_user(SUPERUSER_EMAIL);
            user.set_password(SUPERUSER_PASSWORD);
            user.is_staff = True;
            user.is_superuser = True;
            user.save();
            print('Superuser created.');
        else:
            print('Superuser creation skipped. Already exists.');
  '';
in
healthchecks.overrideAttrs (oldAttrs: {
  installPhase = oldAttrs.installPhase + ''
    cp ${createSuperuser} $out/opt/healthchecks/hc/create_superuser.py
  '';
})
