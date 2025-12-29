{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.beets;
  
  # Import beetcamp package
  beetcamp = pkgs.callPackage ../../../pkgs/beetcamp.nix { };
  
  # Create custom beets with plugins
  beetsWithPlugins = pkgs.python3Packages.beets.override {
    pluginOverrides = {
      bandcamp = {
        enable = true;
        propagatedBuildInputs = [ beetcamp ];
      };
    };
  };
  
  # Create wrapper script that calls the real beet binary
  beet-wrapper = pkgs.writeScriptBin "beet" ''
    #!${pkgs.python3}/bin/python3
    
    import pathlib
    import os
    import argparse
    import subprocess
    import itertools
    from typing import List

    # Use the custom beets with plugins
    _BEET = "${beetsWithPlugins}/bin/beet"

    # Config directory will be set by Nix module
    _CONFIG_DIR = pathlib.Path.home() / ".config" / "beets"

    _CONFIG_EXTENSIONS = {
        "music": [".mp3"],
        "lossless": [".flac"],  # only supporting flac here
        "vinyl": [".flac"],
    }

    _GLOB_EXTENSIONS = set(itertools.chain.from_iterable(_CONFIG_EXTENSIONS.values()))


    def _get_config(config: str) -> pathlib.Path:
        config_loc = _CONFIG_DIR / f"config-{config}.yaml"
        if not config_loc.exists():
            raise Exception(f"config for {config} not found at {config_loc}")
        return config_loc


    def _importing_correct_extension(config: str, import_path_s: str):
        import_path = pathlib.Path(import_path_s)
        if not import_path.exists():
            raise Exception(f"the import path does not exist: {import_path}")
        expected_exts = _CONFIG_EXTENSIONS[config]
        unexpected_exts = [x for x in _GLOB_EXTENSIONS if x not in expected_exts]
        files = []
        for ext in unexpected_exts:
            ext_files = list(import_path.glob(f"**/*{ext}"))
            if ext_files:
                raise Exception(
                    f"config {config} expected extensions {expected_exts} but found {ext} files"
                )


    def validate(args) -> pathlib.Path:
        config = _get_config(args.config)
        beet_cmd = args.beet_args[0]
        if beet_cmd == "import":
            import_path = args.beet_args[1]
            _importing_correct_extension(args.config, import_path)
        return config


    def invoke_beet(config_file: pathlib.Path, beet_args: List[str], unknown_args: List[str]):
        cmd = [_BEET, "--config", str(config_file)] + beet_args + unknown_args
        subprocess.run(cmd)


    def _parse_args():
        parser = argparse.ArgumentParser(description="Wrapper around beets for safeguards", add_help=False)
        parser.add_argument(
            "config",
            type=str,
            choices=_CONFIG_EXTENSIONS.keys(),
            help="the config to target",
        )
        parser.add_argument("beet_args", nargs="+", help="the command to pass to beets")
        return parser.parse_known_args()


    def main():
        args, unknown_args = _parse_args()
        config_file = validate(args)
        invoke_beet(config_file, args.beet_args, unknown_args)


    if __name__ == "__main__":
        main()
  '';

in {
  options.modules.beets = { 
    enable = mkEnableOption "Beets music library manager with multi-library support"; 
  };

  config = mkIf cfg.enable {
    # Install only the wrapper (which internally calls beets)
    home.packages = [
      beet-wrapper
    ];

    # Install the three config files to ~/.config/beets/
    home.file.".config/beets/config-music.yaml" = {
      source = ./config-music.yaml;
    };

    home.file.".config/beets/config-vinyl.yaml" = {
      source = ./config-vinyl.yaml;
    };

    home.file.".config/beets/config-lossless.yaml" = {
      source = ./config-lossless.yaml;
    };

    # Note: We're not using programs.beets.enable because we need multiple
    # configs. The wrapper script will handle selecting the right config.
  };
}

