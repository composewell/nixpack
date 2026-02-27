# Copyright   : (c) 2022 Composewell Technologies
# For faster build using less space we disable profiling
# XXX pass profiling as an option
{ nixpkgs, libDepends, withHaddock }:
let
  libUtils = import ./lib.nix;

  overrideHackage = super: pkg: ver: sha256: prof:
    let
      src =
        { pkg = pkg;
          ver = ver;
          sha256 = sha256;
        };
      options =
        { enableLibraryProfiling = prof;
          doHaddock = withHaddock;
          doCheck = false;
        };
      orig = super.callHackageDirect src {};
    in hlib.overrideCabal orig (old: options);

  hlib = nixpkgs.haskell.lib;

  overrideOptions = flags: prof:
    {
      librarySystemDepends = libDepends;
      enableLibraryProfiling = prof;
      doHaddock = withHaddock;
      doCheck = false;
      configureFlags = flags;
    };

  origDrv = super: drvLabel: path: subdir: c2nix:
    assert libUtils.isPathLike "origDrv" path;
    let loc = if subdir == "" then path else path + "/${subdir}";
    in
      super.callCabal2nixWithOptions
          drvLabel
          loc
          (builtins.concatStringsSep " " c2nix)
          {};

  # we can possibly avoid adding our package to HaskellPackages like
  # in the case of nix-shell for a single package?
  overrideLocalHaskell = super: drvLabel: path: subdir: c2nix: flags: prof:
    let
      orig = origDrv super drvLabel path subdir c2nix;
      drv = hlib.overrideCabal orig (old: overrideOptions flags prof);
    in
      # Keep live source, don't copy to /nix/store
      drv.overrideAttrs (_: { src = path; });

  # XXX Use nixpkgs.fetchgit with sha256 for reproducibility
  overrideGitHaskell = super: drvLabel: url: rev: branch: subdir: c2nix: flags: prof:
    #builtins.trace "url=${url}"
    let
      path = fetchGit {
        url = url;
        rev = rev;
        ref = branch;
      };
      orig = origDrv super drvLabel path subdir c2nix;
    in hlib.overrideCabal orig (old: overrideOptions flags prof);

  deriveGitCopy = super: drvLabel: url: rev: branch: inlineBins: tagLocal:
    # Note super is haskellPackages, we need to pass nixpkgs for lib
    libUtils.copyRepo1 nixpkgs drvLabel url rev branch inlineBins tagLocal;

  deriveLocalCopy = super: drvLabel: path: inlineBins: tagLocal:
    assert libUtils.isPathLike "deriveLocalCopy" path;
    # Note super is haskellPackages, we need to pass nixpkgs for lib
    libUtils.copyPath1 nixpkgs drvLabel path inlineBins tagLocal;

  deriveGitImport = super: drvLabel: url: rev: branch: subdir:
    let
      src = fetchGit {
          url = url;
          rev = rev;
          ref = branch;
      };
      loc = if subdir == "" then src else src + "/${subdir}";
    in import loc {inherit nixpkgs;};

  deriveLocalImport = super: drvLabel: path: subdir:
    assert libUtils.isPathLike "deriveLocalCopy" path;
    let
      loc = if subdir == "" then path else path + "/${subdir}";
    in import loc {inherit nixpkgs;};

makeOverrides = super: sources:
  builtins.mapAttrs (name: spec:
    let
      type   = spec.type;
      build  = spec.build or "haskell";

      # Location
      branch = spec.branch or "master";
      subdir = spec.subdir or "";

      # Haskell build options
      c2nix  = spec.c2nix  or [];
      flags  = spec.flags  or [];
      prof   = spec.profiling or false;

      # Copy build options
      inlineBins = spec.inlineBins or [];
      tagLocal = spec.tagLocal or true;
    in

    if type == "hackage" then
      if build == "haskell" then
        overrideHackage super name spec.version spec.sha256 prof
      else
        throw "Unknown build type for Hackage source: ${build}"

    else if type == "git" then
      if build == "haskell" then
        overrideGitHaskell super name spec.url spec.rev branch subdir c2nix flags prof
      else if build == "copy" then
        deriveGitCopy super name spec.url spec.rev branch inlineBins tagLocal
      else if build == "import" then
        deriveGitImport super name spec.url spec.rev branch subdir
      else
        throw "Unknown build type for git source: ${build}"

    else if type == "local" then
      if build == "haskell" then
        overrideLocalHaskell super name spec.path subdir c2nix flags prof
      else if build == "copy" then
        #builtins.trace "name=${name}"
        # XXX can add subdir here as well
        deriveLocalCopy super name spec.path inlineBins tagLocal
      else if build == "import" then
        deriveLocalImport super name spec.path subdir
      else
        throw "Unknown build type for local source: ${build}"

    else
      throw "Unknown package source type: ${type}"
  ) sources;

in makeOverrides
