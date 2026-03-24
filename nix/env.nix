{ nixpkgs,
  basepkgs,
  name,
  packages,
  sources ? {nixpack}: {},
  # Use default to utilize the cache, use specific compiler for reproducibility
  compiler ? "default",
  installHoogle ? false,
  installDocs ? false
}:
let

  sources1 =
    basepkgs.nixpack.lib.mergeSources
      basepkgs.sources (sources {nixpack = basepkgs.nixpack;});

  cocoa = if builtins.match ".*darwin.*" nixpkgs.system != null then
    [ nixpkgs.darwin.apple_sdk.frameworks.Cocoa ]
  else
    [ ];

  mkoverrides = (import ./overrides.nix) {
    inherit nixpkgs;
    libDepends = cocoa;
    withHaddock = installHoogle;
  };

  haskellPackagesOrig = if compiler == "default" then
    nixpkgs.haskellPackages
  else
    nixpkgs.haskell.packages.${compiler};

  foldExtend = layers: base:
    builtins.foldl' (acc: srcs:
        let overrides = self: super: mkoverrides super srcs;
        in acc.extend overrides
    ) base layers;

  allLayers =
    foldExtend
      (if sources1 ? layers then sources1.layers else [])
      haskellPackagesOrig;

  haskellPackages =
    if sources1 ? jailbreaks then
      let
        overrides = self: super:
          with nixpkgs.haskell.lib;
          builtins.listToAttrs (map (name: {
            inherit name;
            value = doJailbreak super.${name};
          }) sources1.jailbreaks);
      in allLayers.extend overrides
    else allLayers;

  nixpkgs1 = nixpkgs.extend (self: super: {
    haskellPackages = haskellPackages;
  });

  reqPkgs = packages
    { nixpkgs = nixpkgs1;
    };

  requiredPackages = {
    packages =
      if reqPkgs ? packages then
        reqPkgs.packages
      else [];
    devPackages =
      if reqPkgs ? dev-packages then
        reqPkgs."dev-packages"
      else [];
    libraries =
      if reqPkgs ? libraries then
        reqPkgs.libraries
      else [];
  };

  # A fake package to add some additional deps to the shell env
  shellPkg = haskellPackages.mkDerivation rec {
    version = "0.1";
    pname = "${name}-shell-pkg";
    license = "BSD-3-Clause";
    src = nixpkgs.emptyDirectory;

    libraryHaskellDepends = requiredPackages.libraries;
    setupHaskellDepends = with haskellPackages; [ cabal-doctest ];
    # XXX On macOS cabal2nix does not seem to generate a
    # dependency on Cocoa framework.
    executableFrameworkDepends = cocoa;
  };

  # XXX we can have a depsOf section in packages.nix such that only
  # dependencies of those packages are installed and not the packages
  # themselves.

  mkshell = (import ./mkshell.nix) {
    inherit nixpkgs;
  };

  shell =
    mkshell haskellPackages (p: [ shellPkg ] ++ requiredPackages.devPackages)
      requiredPackages.packages installHoogle true;

  env = nixpkgs.buildEnv {
      name = "${name}";
      paths = requiredPackages.packages ++ requiredPackages.libraries;
      pathsToLink = [ "/share" "/bin" "/local" "/etc" "/lib" "/libexec" "/include" ];
      extraOutputsToInstall =
        if installDocs then
          [ "man"
            "doc"
            "info"
            # "dev"
          ]
        else [];
  };

in {
  nixpkgs = nixpkgs1;
  inherit shell;
  inherit env;
  sources = sources1;
}
