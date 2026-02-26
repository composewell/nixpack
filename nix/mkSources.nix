let
#--------------------------------------------------------------------------
# Declaring packages
#--------------------------------------------------------------------------

# type: "hackage"
#   version:
#   sha256:
#   profiling:

  hackage = version: sha256: {
    type = "hackage";
    inherit version sha256;
    profiling = false;
  };

  hackageProf = version: sha256: {
    type = "hackage";
    inherit version sha256;
    profiling = true;
  };

# Example:
#  streamly-core = {
#   type = "git";
#   url = "/x/y";
#   rev = "b469a10f4f7f4d9ebaad828ba008dd7ac6f04849";
#
#   branch = "master";
#   subdir = "/core";
#   build = "copy"; # "haskell"
#   # Haskell build options
#   c2nix = []; # cabal2nix options
#   flags = []; # configure flags
#  };

# Example:
#  streamly-core = {
#   type = "github";
#   https = false;
#   owner = "composewell";
#   repo = "streamly";
#   rev = "b469a10f4f7f4d9ebaad828ba008dd7ac6f04849";
#
#   branch = "custom";
#   subdir = "/core";
#   build = "copy"; # "haskell"
#   # Haskell build options
#   c2nix = []; # cabal2nix options
#   flags = []; # configure flags
#  };

  mkGithubURL = owner: repo:
    "git@github.com:${owner}/${repo}.git";

  mkGithubHttpsURL = owner: repo:
    "https://github.com/${owner}/${repo}.git";

  githubAll = owner: repo: rev: branch: subdir: c2nix: flags: {
    type = "github";
    https = false;
    inherit owner repo rev branch subdir c2nix flags;
  };

  master = "master";

  githubBranchOpts = owner: repo: rev: branch: c2nix: flags:
    githubAll owner repo rev branch "" c2nix flags;

  githubOpts = owner: repo: rev: c2nix: flags:
    githubBranchOpts owner repo rev master c2nix flags;

  githubBranch = owner: repo: rev: branch:
    githubBranchOpts owner repo rev branch [] [];

  githubSubdir = owner: repo: rev: subdir:
    githubAll owner repo rev master subdir [] [];

  github = owner: repo: rev:
    githubOpts owner repo rev [] [];

# type: "local"
#   path:
#   c2nix:
#   flags:

  localOpts = path: c2nix: flags: {
    type = "local";
    inherit path c2nix flags;
  };

  local = path:
    localOpts path [] [];

in
{
  inherit hackage;
  inherit hackageProf;

  inherit mkGithubURL;
  inherit mkGithubHttpsURL;

  inherit githubBranchOpts;
  inherit githubOpts;
  inherit githubBranch;
  inherit githubSubdir;
  inherit github;

  inherit localOpts;
  inherit local;
}
