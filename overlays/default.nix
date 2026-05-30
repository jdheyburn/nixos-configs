inputs:
let inherit inputs;
in final: prev: {

  victoriametrics-enterprise = prev.callPackage ./victoriametrics-enterprise { };

  obsidian-headless = prev.callPackage ./obsidian-headless { };

}
