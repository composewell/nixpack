let
#--------------------------------------------------------------------------
# Declaring packages
#--------------------------------------------------------------------------

# Example:
#  streamly-core = {
#   type = "hackage";
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
#
#   # ssh (git@github.com/) or https (https://github.com/) url
#   url = "https://github.com/composewell/streamly";
#   rev = "b469a10f4f7f4d9ebaad828ba008dd7ac6f04849";
#   branch = "custom";
#
#   build = "haskell"; # or "copy"
#
#   # When build == "haskell"
#   subdir = "core";
#   c2nix = []; # cabal2nix options
#   flags = []; # configure flags
#
#   # When build == "copy"
#   # Copies the bin, etc directories from the source
#   # See copyRepo function in nixpack
#   inlineBins = []; # Additional files to put in bin dir
#   tagLocal = true; # symlink the bins in ~/.nix-profile/local
#  };

  mkGithubURL = owner: repo:
    "git@github.com:${owner}/${repo}.git";

  mkGithubHttpsURL = owner: repo:
    "https://github.com/${owner}/${repo}.git";

  githubAll = owner: repo: rev: branch: subdir: c2nix: flags: {
    type = "git";
    url = mkGithubURL owner repo;
    inherit rev branch subdir c2nix flags;
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

# Example:
#  some-utils = {
#   type = "local";
#
#   path = /x/y; # local file system path
#
#   # Rest of the options same as type = "git".
#  };
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
