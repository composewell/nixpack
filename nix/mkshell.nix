# Copyright   : (c) 2022 Composewell Technologies
{ nixpkgs }:
let
  # XXX we should move this to packages.nix
  cocoa = if builtins.match ".*darwin.*" nixpkgs.system != null then
    [ nixpkgs.darwin.apple_sdk.frameworks.Cocoa ]
  else
    [ ];

  mkShell = hpkgs: pkgs: inputs: doHoogle: doBench:
    hpkgs.shellFor {
      packages = pkgs;
      # some dependencies of hoogle fail to build with quickcheck-2.14
      # We should use hoogle as external tool instead of building it here
      withHoogle = doHoogle;
      doBenchmark = doBench;
      # XXX On macOS cabal2nix does not seem to generate a dependency on
      # Cocoa framework.
      buildInputs = inputs ++ cocoa;
      # Use a better prompt
      shellHook = ''
        # We use an empty cabal config to force default config
        export CABAL_CONFIG=/dev/null

        # If desired we can use a custom cabal config file and set
        # specific config params using cabal user-config update.
        #CFG_DIR="$HOME/.config/streamly-packages"
        #CFG_FILE="$CFG_DIR/config.empty"
        #mkdir -p "$CFG_DIR"
        #export CABAL_DIR="$CFG_DIR"
        #This is commented for hls to work with VSCode
        #cabal user-config update -a "jobs: 1"

        # Modify the prompt to make the user aware that they are in
        # a nix shell.  However we just source the shell rc file and
        # prompt can be set there as desired.
        # export PS1="$PS1(haskell) "

        # Nix does not source the user's bashrc by default.
        # Invoke the rc file to set your usual shell environment
        # including the prompt. You can use the IN_NIX_SHELL env var to
        # set a nix specific prompt if needed.
        case "$SHELL" in
          */bash)
            # Source Bash config only if file exists and shell is interactive
            if [ -n "$PS1" ] && [ -f "$HOME/.bashrc" ]; then
              . "$HOME/.bashrc"
            fi
            ;;
          */zsh)
            # Source Zsh RC
            if [ -o interactive ] && [ -f "$HOME/.zshrc" ]; then
              . "$HOME/.zshrc"
            fi
            ;;
          */fish)
            # Fish uses a different syntax: we invoke fish explicitly
            if [ -f "$HOME/.config/fish/config.fish" ]; then
              fish --private -C "source $HOME/.config/fish/config.fish"
            fi
            ;;
          *)
            # Generic POSIX shell: only source .profile if interactive
            if [ -n "$PS1" ] && [ -f "$HOME/.profile" ]; then
              . "$HOME/.profile"
            fi
            ;;
        esac
      '';
    };

in mkShell
