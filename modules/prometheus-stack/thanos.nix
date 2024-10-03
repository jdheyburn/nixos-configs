{ catalog, config, pkgs }:
let objstore_config = config.age.secrets."thanos-objstore-config".path;
in {
  sidecar = {
    enable = config.modules.prometheusStack.thanos.enable;
    prometheus.url =
      "http://localhost:${toString catalog.services.prometheus.port}";

    http-address = "0.0.0.0:${toString catalog.services.thanos-sidecar.port}";
    grpc-address =
      "0.0.0.0:${toString catalog.services.thanos-sidecar.grpcPort}";

    objstore.config-file = objstore_config;
  };

  store = {
    enable = config.modules.prometheusStack.thanos.enable;
    http-address = "0.0.0.0:${toString catalog.services.thanos-store.port}";
    grpc-address = "0.0.0.0:${toString catalog.services.thanos-store.grpcPort}";
    objstore.config-file = objstore_config;
  };

  query = {
    enable = config.modules.prometheusStack.thanos.enable;

    http-address = "0.0.0.0:${toString catalog.services.thanos-query.port}";
    grpc-address = "0.0.0.0:${toString catalog.services.thanos-query.grpcPort}";

    # This option is no longer available and so produces an error
    # I'm not sure what its replaced with, so leaving it here in case I come back to thanos
    #  store.addresses = [
    #   "localhost:${toString catalog.services.thanos-sidecar.grpcPort}"
    #   "localhost:${toString catalog.services.thanos-store.grpcPort}"
    # ];
  };
}
