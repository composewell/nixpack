{
  description = "Dev project";

  # Replace "nixpack" with your super package set
  inputs = {
    basepkgs.url = "github:composewell/nixpack/b3db598aa29533646b13a94aca3fee8ead622d06";
    nixpkgs.follows = "basepkgs/nixpkgs";
    nixpkgs-darwin.follows = "basepkgs/nixpkgs-darwin";
  };

  outputs = { self, nixpkgs, nixpkgs-darwin, basepkgs }:
    basepkgs.nixpack.mkOutputs {
      inherit nixpkgs nixpkgs-darwin basepkgs;
      name = "my-project";
      # Simpler, single package inline declaration
      sources = basepkgs.nixpack.lib.localSource "pkgname" ./.;
      packages = basepkgs.nixpack.lib.devPackage "pkgname";

      # Use files as usual for more complicated multiple dev packages
      #sources = import ./sources.nix;
      #packages = import ./packages.nix;
    };
}
