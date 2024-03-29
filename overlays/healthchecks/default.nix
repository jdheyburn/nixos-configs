# Forked from https://github.com/NixOS/nixpkgs/blob/69940c042cb6a0f2db1f3696fb5b78defde28470/pkgs/servers/web-apps/healthchecks/default.nix
# Made changes to local_settings.py

# Forked from https://github.com/NixOS/nixpkgs/blob/69940c042cb6a0f2db1f3696fb5b78defde28470/pkgs/servers/web-apps/healthchecks/default.nix
# Made changes to local_settings.py

{ lib
, writeText
, fetchFromGitHub
, nixosTests
, python3
}:
let
  py = python3.override {
    packageOverrides = final: prev: {
      django = prev.django_4;
    };
  };
in
py.pkgs.buildPythonApplication rec {
  pname = "healthchecks";
  version = "2.10";
  format = "other";

  src = fetchFromGitHub {
    owner = "healthchecks";
    repo = pname;
    rev = "refs/tags/v${version}";
    sha256 = "sha256-1x+pYMHaKgLFWcL1axOv/ok1ebs0I7Q+Q6htncmgJzU=";
  };

  propagatedBuildInputs = with py.pkgs; [
    apprise
    cron-descriptor
    cronsim
    django
    django-compressor
    fido2
    minio
    psycopg2
    pycurl
    pyotp
    segno
    statsd
    whitenoise
  ];

  localSettings = writeText "local_settings.py" ''
    import os
    STATIC_ROOT = os.getenv("STATIC_ROOT")
    SECRET_KEY_FILE = os.getenv("SECRET_KEY_FILE")
    if SECRET_KEY_FILE:
        with open(SECRET_KEY_FILE, "r") as file:
            SECRET_KEY = file.readline()
    EMAIL_HOST_PASSWORD_FILE = os.getenv("EMAIL_HOST_PASSWORD_FILE")
    if EMAIL_HOST_PASSWORD_FILE:
        with open(EMAIL_HOST_PASSWORD_FILE, "r") as file:
            EMAIL_HOST_PASSWORD = file.readline()
  '';

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

  installPhase = ''
    mkdir -p $out/opt/healthchecks
    cp -r . $out/opt/healthchecks
    chmod +x $out/opt/healthchecks/manage.py
    cp ${localSettings} $out/opt/healthchecks/hc/local_settings.py
    cp ${createSuperuser} $out/opt/healthchecks/hc/create_superuser.py
  '';

  passthru = {
    # PYTHONPATH of all dependencies used by the package
    pythonPath = py.pkgs.makePythonPath propagatedBuildInputs;

    tests = { inherit (nixosTests) healthchecks; };
  };

  meta = with lib; {
    homepage = "https://github.com/healthchecks/healthchecks";
    description = "A cron monitoring tool written in Python & Django ";
    license = licenses.bsd3;
    maintainers = with maintainers; [ phaer ];
  };
}

