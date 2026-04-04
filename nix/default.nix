let
  disableProfiling = nixpkgs: pkg:
    nixpkgs.haskell.lib.overrideCabal pkg
    (old: { enableLibraryProfiling = false; });
in
{
  # High level function for use in flake.nix and shell.nix
  mkEnv = import ./env.nix;
  mkOutputs = import ./mkOutputs.nix;
  mkOutputsSimple = import ./mkOutputsSimple.nix;

  # lower level utility functions
  mkShell = import ./mkshell.nix;
  #mkOverrides = import ./overrides.nix;
  inherit disableProfiling; # used for creating pkg flakes, see README.

# utility functions to declare sources.
  mkSources = import ./mkSources.nix;
# takes sources, returns derivation.
  listSources = import ./list-sources.nix;
  lib = import ./lib.nix;
}
