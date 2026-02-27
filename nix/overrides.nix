# Copyright   : (c) 2022 Composewell Technologies
# For faster build using less space we disable profiling
# XXX pass profiling as an option
{ nixpkgs, libDepends, withHaddock }:
let
  sourceUtils = import ./mkSources.nix;
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

  # we can possibly avoid adding our package to HaskellPackages like
  # in the case of nix-shell for a single package?
  overrideLocalHaskell = super: drvLabel: path: subdir: c2nix: flags: prof:
    let
      orig = super.callCabal2nixWithOptions
        drvLabel
        "${builtins.toString path}/${subdir}"
        (builtins.concatStringsSep " " c2nix)
        {};
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
      orig = super.callCabal2nixWithOptions
        drvLabel
        "${path}/${subdir}"
        (builtins.concatStringsSep " " c2nix)
        {};
    in hlib.overrideCabal orig (old: overrideOptions flags prof);

  deriveGitCopy = super: drvLabel: url: rev: branch: xfiles:
    libUtils.copyRepo1 nixpkgs drvLabel url rev branch xfiles;

  deriveLocalCopy = super: drvLabel: path: xfiles:
    throw "Copy build type in local repo not implemented";

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
      xfiles = spec.xfiles or [];
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
        deriveGitCopy super spec.url spec.rev branch xfiles
      else
        throw "Unknown build type for git source: ${build}"

    else if type == "local" then
      if build == "haskell" then
        overrideLocalHaskell super name spec.path subdir c2nix flags prof
      else if build == "copy" then
        deriveLocalCopy super spec.path xfiles
      else
        throw "Unknown build type for local source: ${build}"

    else
      throw "Unknown package source type: ${type}"
  ) sources;

in makeOverrides
