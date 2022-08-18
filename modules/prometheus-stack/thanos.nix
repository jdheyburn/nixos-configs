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

    http-address = "0.0.0.0:${toString catalog.services.thanos-sidecar.port}";
    grpc-address =
      "0.0.0.0:${toString catalog.services.thanos-sidecar.grpcPort}";

    objstore.config = objstore_config;
  };

  store = {
    enable = true;
    http-address = "0.0.0.0:${toString catalog.services.thanos-store.port}";
    grpc-address = "0.0.0.0:${toString catalog.services.thanos-store.grpcPort}";
    objstore.config = objstore_config;
  };

  query = {
    enable = true;

    http-address = "0.0.0.0:${toString catalog.services.thanos-query.port}";
    grpc-address = "0.0.0.0:${toString catalog.services.thanos-query.grpcPort}";

    store.addresses =
      [ "localhost:${toString catalog.services.thanos-store.grpcPort}" ];
  };
}
