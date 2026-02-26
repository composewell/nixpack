# Copyright   : (c) 2022 Composewell Technologies
# For faster build using less space we disable profiling
# XXX pass profiling as an option
{ nixpkgs, libDepends, withHaddock }:
let
  sourceUtils = import ./mkSources.nix;
  libUtils = import ./lib.nix;

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
  deriveLocalHaskell = super: path: c2nix: flags: prof:
  let
    drvLabel = builtins.baseNameOf path;
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
  deriveGitHaskell = super: url: rev: branch: subdir: c2nix: flags: prof:
    #builtins.trace "url=${url}"
    (nixpkgs.haskell.lib.overrideCabal (let
      src = fetchGit {
        url = url;
        rev = rev;
        ref = branch;
      };
      drvLabel = builtins.baseNameOf url;
    in super.callCabal2nixWithOptions drvLabel "${src}${subdir}" (builtins.concatStringsSep " " c2nix) { }
    ) (old: {
      librarySystemDepends = libDepends;
      enableLibraryProfiling = prof;
      doHaddock = withHaddock;
      doCheck = false;
      configureFlags = flags;
    }));

  deriveGitCopy = super: url: rev: branch: xfiles:
    let drvLabel = builtins.baseNameOf url;
    in libUtils.copyRepo1 nixpkgs drvLabel url rev branch xfiles;

  deriveLocalCopy = super: path: xfiles:
    let drvLabel = builtins.baseNameOf path;
    in throw "Copy build type in local repo not implemented";

  makeOverrides = super: sources:
    builtins.mapAttrs (name: spec:
      if spec.type == "hackage" then
        # build = copy is invalid in this case
        let
          prof = if spec ? profiling then spec.profiling else false;
        in
        if prof == true then
          deriveHackageProf super name spec.version spec.sha256
        else deriveHackage super name spec.version spec.sha256
      else
        let
          branch = if spec ? branch then spec.branch else "master";
          build = if spec ? build then spec.build else "haskell";
          # Haskell build only options
          subdir = if spec ? subdir then spec.subdir else "";
          c2nix = if spec ? c2nix then spec.c2nix else [];
          flags = if spec ? flags then spec.flags else [];
          prof = if spec ? profiling then spec.profiling else false;
          # Copy build only options
          xfiles = if spec ? xfiles then spec.xfiles else [];
        in
        if spec.type == "git" then
             if build == "haskell"
             then deriveGitHaskell super spec.url spec.rev branch subdir c2nix flags prof
             else if build == "copy"
             then deriveGitCopy super spec.url spec.rev branch xfiles
             else throw "Unknown build type: ${build}"
      else if spec.type == "local" then
             if build == "haskell"
             then deriveLocalHaskell super spec.path spec.c2nix spec.flags prof
             else if build == "copy"
             then deriveLocalCopy super spec.path xfiles
             else throw "Unknown build type: ${build}"
      else
        throw "Unknown package source type: ${spec.type}"
    ) sources;

in makeOverrides
