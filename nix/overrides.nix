# Copyright   : (c) 2022 Composewell Technologies
# For faster build using less space we disable profiling
# XXX pass profiling as an option
{ nixpkgs, libDepends, withHaddock }:
let
  libUtils = import ./lib.nix;
  mkSources = import ./mkSources.nix;

  overrideNixpkgs = super: pkgName: prof: flags: forceVer:
    let
      # Grab the existing package from the Haskell set
      orig = super.${pkgName};
      
      options = {
        # Do not change anything to unnecessarily recompile
        enableLibraryProfiling = prof;
        # XXX use default for these when not specified
        #doHaddock = withHaddock; # Assumes withHaddock is in scope
        #doCheck = false;
        configureFlags = flags;
      };
    in
      assert nixpkgs.lib.assertMsg (forceVer == null || forceVer == orig.version)
        "Version of ${pkgName} must be ${forceVer} but is ${orig.version}";
      hlib.overrideCabal orig (old: options);

  /*
  # This gets the oldest revision on hackage.
  overrideHackage = super: pkg: ver: sha256: prof: flags:
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
          configureFlags = flags;
        };
      orig = super.callHackageDirect src {};
    in hlib.overrideCabal orig (old: options);
  */

  # This gets the latest revision from hackage.
  overrideHackage = super: pkg: ver: rev: sha256: cabalSha256: prof: flags:
    let
      # 1. Always fetch the base source tarball
      src = builtins.fetchTarball {
        url = "https://hackage.haskell.org/package/${pkg}-${ver}/${pkg}-${ver}.tar.gz";
        sha256 = sha256;
      };

      # 2. Only fetch the latest cabal revision if a hash is provided
      latestCabal = if cabalSha256 != null then
        builtins.fetchurl {
          #url = "https://hackage.haskell.org/package/${pkg}-${ver}/revisions/latest.cabal";
          url = "https://hackage.haskell.org/package/${pkg}-${ver}/revision/${rev}.cabal";
          sha256 = cabalSha256;
        }
      else null;

      orig = super.callCabal2nix pkg src { };
      
      # 3. Build the options set
      options = {
        enableLibraryProfiling = prof;
        doHaddock = withHaddock;
        doCheck = false;
        configureFlags = flags;
      };
    in
      hlib.overrideCabal orig (old: options // (
        # Only apply the postPatch if we actually downloaded a new cabal file
        if latestCabal != null then {
          postPatch = (old.postPatch or "") + ''
            cp ${latestCabal} ${pkg}.cabal
          '';
        } else {}
      ));

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

  overrideNpm = super: drvLabel: scope: version: sha256: npmDepsHash: packageLockJson: extraAttrs:
    let
      urlName = if scope == "" then drvLabel else "@${scope}/${drvLabel}";
      tarName = "${drvLabel}-${version}.tgz";
      src = nixpkgs.fetchzip {
        url = "https://registry.npmjs.org/${urlName}/-/${tarName}";
        hash = sha256;
      };
      # Packages fetched from the npm registry use fetchzip rather
      # than fetchGit, so git-specific attributes like rev, shortRev,
      # lastModified etc. are absent.  We patch them onto the src
      # with sensible fallbacks so derivations that reference these
      # attributes (e.g. to embed a build version) don't fail.
      srcWithLock =
        let
          base = if packageLockJson == null then src else
            nixpkgs.runCommand "source-with-lock" {} ''
              cp -r ${src} $out
              chmod -R u+w $out
              cp ${packageLockJson} $out/package-lock.json
            '';
        in base // {
          rev = version;
          shortRev = builtins.substring 0 7 version;
          revCount = 0;
          lastModified = 0;
          lastModifiedDate = "19700101000000";
          narHash = src.narHash;
        };
    in super.${drvLabel}.overrideAttrs (old: {
        inherit version;
        src = srcWithLock;
        npmDeps = nixpkgs.fetchNpmDeps {
          src = srcWithLock;
          hash = npmDepsHash;
        };
        # These do not apply to pre-built npm tarballs.
        dontNpmBuild = true;
        postPatch = "";
        installPhase = null;
        postInstall = "";
        preConfigure = "";
      } // extraAttrs super);

  deriveGitCopy = super: drvLabel: url: rev: branch: binFiles: tagLocal:
    # Note super is haskellPackages, we need to pass nixpkgs for lib
    libUtils.copyRepo1 nixpkgs drvLabel url rev branch binFiles tagLocal;

  deriveLocalCopy = super: drvLabel: path: binFiles: tagLocal:
    assert libUtils.isPathLike "deriveLocalCopy" path;
    # Note super is haskellPackages, we need to pass nixpkgs for lib
    libUtils.copyPath1 nixpkgs drvLabel path binFiles tagLocal;

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

# Convert githost type to git type.
preProcessGitHost = name: spec:
    let
      # githost type options
      https = spec.https or true;
      user = spec.user or "git";
      localPrefix = spec.localPrefix or null;

      url =
        if localPrefix != null then
          localPrefix + "/${spec.repo}"
        else if https then
          "https://${spec.host}/${spec.owner}/${spec.repo}.git"
        else
          "${user}@${spec.host}:${spec.owner}/${spec.repo}.git";
    in spec // { type = "git"; inherit url; };

processSpec = super: name: spec:
    let
      type   = spec.type;
      build  = spec.build or "haskell";

      # Location
      branch = spec.branch or mkSources.defaultBranch;
      subdir = spec.subdir or "";

      forceVer = spec.version or null;

      # Haskell build options
      c2nix  = spec.c2nix  or [];
      flags  = spec.flags  or [];
      prof   = spec.profiling or false;
      revision = spec.rev or null;
      cabalSha256 =
        if revision != null
        then
          spec.cabalSha256
        else null;

      # Copy build options
      binFiles = spec.binFiles or [];
      tagLocal = spec.tagLocal or true;

      # npmjs build options
      scope        = spec.scope        or "";
      version      = spec.version      or "";
      sha256       = spec.sha256       or "";
      npmDepsHash  = spec.npmDepsHash  or "";
      packageLockJson = spec.packageLockJson or null;
      extraAttrs   = spec.extraAttrs   or (pkgs: {});

    in

    if type == "nixpkgs" then
        overrideNixpkgs super name (spec.profiling or true) flags forceVer

    #--------------------------------------------------------------------------
    # Hackage
    #--------------------------------------------------------------------------

    else if type == "hackage" then
        overrideHackage super name spec.version revision spec.sha256 cabalSha256 prof flags

    #--------------------------------------------------------------------------
    # git
    #--------------------------------------------------------------------------

    else if type == "git" then
      if build == "haskell" then
        overrideGitHaskell super name spec.url spec.rev branch subdir c2nix flags prof
      else if build == "copy" then
        deriveGitCopy super name spec.url spec.rev branch binFiles tagLocal
      else if build == "import" then
        deriveGitImport super name spec.url spec.rev branch subdir
      else
        throw "Unknown build type for git source: ${build}"

    #--------------------------------------------------------------------------
    # local
    #--------------------------------------------------------------------------

    else if type == "local" then
      if build == "haskell" then
        overrideLocalHaskell super name spec.path subdir c2nix flags prof
      else if build == "copy" then
        #builtins.trace "name=${name}"
        # XXX can add subdir here as well
        deriveLocalCopy super name spec.path binFiles tagLocal
      else if build == "import" then
        deriveLocalImport super name spec.path subdir
      else
        throw "Unknown build type for local source: ${build}"

    else if type == "npmjs" then
        overrideNpm nixpkgs name scope version sha256 npmDepsHash packageLockJson extraAttrs

    else
      throw "Unknown package source type: ${type}";

# XXX when build is "copy"/"import" instead of going to haskellPackages we
# should put them in localPackages. These are not overrides. Anything that is
# not an override should go in localPackages.
makeOverrides = super: sources:
  builtins.mapAttrs (name: spec:
    let spec1 =
          if spec.type == "githost" then
            preProcessGitHost name spec
          else spec;
    in
      #builtins.trace "name=${name}"
        (processSpec super name spec1)
  ) sources;

in makeOverrides
