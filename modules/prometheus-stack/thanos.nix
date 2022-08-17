{ catalog, config, pkgs }:
let

  objstore_config = {
    type = "FILESYSTEM";
    config.directory = "/var/lib/thanos/chunks";
    prefix = "";
  };
in {
  sidecar = {
    enable = true;
    prometheus.url =
      "http://localhost:${toString catalog.services.prometheus.port}";

    grpc-address = "0.0.0.0:10901";

    objstore.config = objstore_config;
  };

  store = {
    enable = true;
    grpc-address = "0.0.0.0:10903";
    objstore.config = objstore_config;
  };

  query = {
    enable = true;

    http-address = "0.0.0.0:${toString catalog.services.thanos-query.port}";
    grpc-address = "0.0.0.0:10902";

    store.addresses = [ "localhost:10903" ];
  };
}

