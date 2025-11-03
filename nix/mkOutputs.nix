{ nixpkgs,
  nixpkgs-darwin,
  systems ?
      [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ],
  nixpkgsOptions ? {},
  basepkgs,
  name,
  packages,
  sources ? {nixpack}: {},
  compiler ? "default",
  installHoogle ? false,
  installDocs ? false
}:

let
  # TODO: remove darwin if nixpkgs-darwin is not specified
  # TODO: remove linux if nixpkgs is not specified

  # TODO: Move this as a lower level helper module
  forAllSystems = f:
    builtins.listToAttrs (map (system: {
      name = system;
      value = f system;
    }) systems);

  mkEnv = system:
    let
      nixpkgs1 =
        if builtins.match ".*darwin.*" system != null
        then nixpkgs-darwin
        else nixpkgs;
      pkgs = import nixpkgs1 (nixpkgsOptions // { inherit system; });
      pkgs1 = pkgs.extend (self: super: {
        nixpack = basepkgs.nixpack;
      });
      env = import ./env.nix {
        nixpkgs = pkgs1;
        inherit basepkgs;
        inherit name;
        inherit packages;
        inherit sources;
        inherit compiler;
        inherit installHoogle;
        inherit installDocs;
      };
    in env;

in {
  devShells = forAllSystems (system: { default = (mkEnv system).shell; });
  packages = forAllSystems (system: (mkEnv system).nixpkgs.haskellPackages);
  nixpkgs = forAllSystems (system: (mkEnv system).nixpkgs);
  # This does not depend on the system
  sources = (mkEnv "x86_64-linux").sources;
  nixpack = basepkgs.nixpack;
}
