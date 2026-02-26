let
  sources = import ./mkSources.nix;

# A simple derivation that copies the bin dir, the etc dir, and additional
# bin files from src to out dir.
copySrc = nixpkgs: { name, src, additionalBinFilesInSrc ? [], localBin ? true }:
  with nixpkgs.pkgs;
  let
    additionalBinFilesAsStr =
      nixpkgs.lib.concatStringsSep " " additionalBinFilesInSrc;
  in
  stdenv.mkDerivation {
    name = name;
    buildInputs = [ coreutils ];
    src = src;
    dontBuild = true;
    phases = [ "installPhase" ];

    installPhase = ''
      set -e

      OUTBIN="$out/bin"

      if [ -d "$src/bin" ] || [ -n "${additionalBinFilesAsStr}" ]; then
        mkdir -p "$OUTBIN"
      fi

      if [ -d "$src/bin" ]; then
        cp -a "$src/bin/." "$OUTBIN/"
      fi

      for file in ${additionalBinFilesAsStr}; do
        cp -a "$src/$file" "$OUTBIN/$file"
      done

      if [ -d "$src/bin" ] || [ -n "${additionalBinFilesAsStr}" ]; then
        chmod +x "$OUTBIN"/*
      fi

      if [ -d "$src/etc" ]; then
        mkdir -p "$out/etc"
        cp -a "$src/etc/." "$out/etc/"
      fi

      if [ -d "$src/share" ]; then
        mkdir -p "$out/share"
        cp -a "$src/share/." "$out/share/"
      fi

      LOCAL=${if localBin then "true" else "false"}
      if [ -d "$out/bin" -a "$LOCAL" = "true" ]
      then
        mkdir -p $out/local
        ln -s $out/bin $out/local/bin
      fi
    '';
  };
in
{
  # XXX omit the name argument get it from the filename in destination
  writeShellScriptTo = nixpkgs: name: destination: text:
    nixpkgs.writeTextFile {
      inherit name;
      inherit destination;
      executable = true;
      text = ''
        #!${nixpkgs.runtimeShell}
        ${text}
        '';
      checkPhase = ''
        ${nixpkgs.stdenv.shell} -n $out${destination}
      '';
    };

  inherit copySrc;

  # Like copySrc but copies from a remote git repo or a git repo at a local
  # file system path.
  copyRepo = nixpkgs: name: spec: {repo_prefix ? null, additionalBinFilesInSrc ? []}:
    copySrc nixpkgs {
      name = "${name}";
      src = fetchGit {
          url =
            if repo_prefix != null
            then "${repo_prefix}/${spec.repo}"
            else
              if spec.https
              then sources.mkGithubHttpsURL spec.owner spec.repo
              else sources.mkGithubURL spec.owner spec.repo;
          rev = spec.rev;
          ref = spec.branch;
      };
      inherit additionalBinFilesInSrc;
    };

  mergeSources = a: b:
  let
    uniq = builtins.foldl' (acc: x:
      if builtins.elem x acc then acc else acc ++ [ x ]
    ) [];

    getLayers = src: if src ? layers then src.layers else [];
    getOthers = src: if src ? others then src.others else {};
    getJailbreaks = src: if src ? jailbreaks then src.jailbreaks else [];
  in {
    layers = getLayers a ++ getLayers b;
    others = getOthers a // getOthers b;
    jailbreaks = uniq (getJailbreaks a ++ getJailbreaks b);
  };

  # Equivalent to a "sources.nix" with "name" as the single source at a local
  # file system "path".
  localSource = name: path: {nixpack}:
      {
        layers = [
        {
          ${name} = nixpack.mkSources.local path;
        }
        ];
      };

  # Equivalent to a "packages.nix" with "name" as the single dev package.
  devPackage = name: {nixpkgs}:
      {
      dev-packages =
      [ nixpkgs.haskellPackages.${name}
      ];
      };
}
