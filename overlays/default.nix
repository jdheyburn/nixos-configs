inputs:
let
  inherit inputs;
in
self: super: {
  forgit = super.callPackage ../pkgs/forgit { inputs = inputs; };
}

