{ lib
, writeText
, fetchFromGitHub
, nixosTests
, python3
}:
let
  py = python3.override {
    self = py;
    packageOverrides = final: prev: {
      django = prev.django_5;
    };
  };
in
py.pkgs.buildPythonApplication rec {
  pname = "healthchecks";
  version = "3.6";
  format = "other";

  src = fetchFromGitHub {
    owner = "healthchecks";
    repo = pname;
    rev = "refs/tags/v${version}";
    sha256 = "sha256-aKt9L3ZgZ8HffcNNJaR+hAI38raWuLp2q/6+rvkl2pM=";
  };

  propagatedBuildInputs = with py.pkgs; [
    aiosmtpd
    apprise
    cronsim
    django
    django-compressor
    django-stubs-ext
    fido2
    minio
    oncalendar
    psycopg2
    pycurl
    pydantic
    pyotp
    segno
    statsd
    whitenoise
  ];

  secrets = [
    "DB_PASSWORD"
    "DISCORD_CLIENT_SECRET"
    "EMAIL_HOST_PASSWORD"
    "LINENOTIFY_CLIENT_SECRET"
    "MATRIX_ACCESS_TOKEN"
    "PD_APP_ID"
    "PUSHBULLET_CLIENT_SECRET"
    "PUSHOVER_API_TOKEN"
    "S3_SECRET_KEY"
    "SECRET_KEY"
    "SLACK_CLIENT_SECRET"
    "TELEGRAM_TOKEN"
    "TRELLO_APP_KEY"
    "TWILIO_AUTH"
  ];

  localSettings = writeText "local_settings.py" ''
    import os

    STATIC_ROOT = os.getenv("STATIC_ROOT")

    ${lib.concatLines (map
      (secret: ''
        ${secret}_FILE = os.getenv("${secret}_FILE")
        if ${secret}_FILE:
            with open(${secret}_FILE, "r") as file:
                ${secret} = file.readline()
      '')
      secrets)}
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

    tests = {
      inherit (nixosTests) healthchecks;
    };
  };

  meta = with lib; {
    homepage = "https://github.com/healthchecks/healthchecks";
    description = "Cron monitoring tool written in Python & Django";
    license = licenses.bsd3;
    maintainers = with maintainers; [ phaer ];
  };
}
