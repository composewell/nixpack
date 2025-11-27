# Copyright   : (c) 2022 Composewell Technologies
# For faster build using less space we disable profiling
# XXX pass profiling as an option
{ nixpkgs, libDepends, withHaddock }:
let
  sourceUtils = import ./mkSources.nix;

  hackageWith = super: pkg: ver: sha256: prof:
    nixpkgs.haskell.lib.overrideCabal
      (super.callHackageDirect
        { pkg = pkg;
          ver = ver;
          sha256 = sha256;
        } {})
      (old:
        { enableLibraryProfiling = prof;
          doHaddock = withHaddock;
          doCheck = false;
        });

  deriveHackageProf = super: pkg: ver: sha256:
    hackageWith super pkg ver sha256 true;

  deriveHackage = super: pkg: ver: sha256:
    hackageWith super pkg ver sha256 false;

  # we can possibly avoid adding our package to HaskellPackages like
  # in the case of nix-shell for a single package?
  deriveLocal = super: drvLabel: path: c2nix: flags: prof:
  let
    fullPath = "${builtins.toString path}";
    drv = nixpkgs.haskell.lib.overrideCabal (
      super.callCabal2nixWithOptions drvLabel fullPath (builtins.concatStringsSep " " c2nix) { }
    ) (old: {
      librarySystemDepends = libDepends;
      enableLibraryProfiling = prof;
      doHaddock = withHaddock;
      doCheck = false;
      configureFlags = flags;
    });
  in
    # Keep live source, don't copy to /nix/store
    drv.overrideAttrs (_: { src = path; });

  # XXX Use nixpkgs.fetchgit with sha256 for reproducibility
  deriveGit = super: drvLabel: url: rev: branch: subdir: c2nix: flags: prof:
    #builtins.trace "url=${url}"
    (nixpkgs.haskell.lib.overrideCabal (let
      src = fetchGit {
        url = url;
        rev = rev;
        ref = branch;
      };
    in super.callCabal2nixWithOptions drvLabel "${src}${subdir}" (builtins.concatStringsSep " " c2nix) { }
    ) (old: {
      librarySystemDepends = libDepends;
      enableLibraryProfiling = prof;
      doHaddock = withHaddock;
      doCheck = false;
      configureFlags = flags;
    }));

  makeOverrides = super: sources:
    builtins.mapAttrs (name: spec:
      if spec.type == "hackage" then
        if spec.profiling == true then
          deriveHackageProf super name spec.version spec.sha256
        else deriveHackage super name spec.version spec.sha256
      else if spec.type == "github" then
        let url =
              if spec.https
              then sourceUtils.mkGithubHttpsURL spec.owner spec.repo
              else sourceUtils.mkGithubURL spec.owner spec.repo;
            drvLabel = "${spec.owner}/${spec.repo}";
        in deriveGit super drvLabel url spec.rev spec.branch spec.subdir spec.c2nix spec.flags false
      else if spec.type == "local" then
        let drvLabel = "local";
        in deriveLocal super drvLabel spec.path spec.c2nix spec.flags false
      else
        throw "Unknown package source type: ${spec.type}"
    ) sources;

in makeOverrides
