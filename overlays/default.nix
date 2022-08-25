inputs:
let
    inherit inputs;
in
self: super: {
    healthchecks = super.callPackage ./healthchecks { };
}
