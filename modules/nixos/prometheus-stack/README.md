# prometheus-stack

Deploys a series of monitoring services that can be used to collect metrics and visualise them.

```nix
modules.prometheusStack.enable = true;
```

## TODO

- [ ] Blackbox exporter should generate config based on services in `catalog.nix`
