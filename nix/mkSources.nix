let
#--------------------------------------------------------------------------
# Declaring packages
#--------------------------------------------------------------------------

# Example:
#  streamly-core = {
#   type = "hackage";
#   version:
#   sha256:
#   profiling: # optional

# Use set overlay for optional fields
  hackage = version: sha256: {
    type = "hackage";
    inherit version sha256;
  };

  hackageProf = version: sha256:
    hackage version sha256 // { profiling = true; };

# Example:
# Where the field is optional default values are filled.
#  streamly = {
#   type = "git";
#
#   # ssh (git@github.com/) or https (https://github.com/) url
#   url = "https://github.com/composewell/streamly";
#   rev = "b469a10f4f7f4d9ebaad828ba008dd7ac6f04849";
#   branch = "master"; # optional
#
#   build = "haskell"; # optional, can be "copy" or "import"
#
#   # When build == "haskell"
#   profiling = false # optional
#   subdir = ""; # optional
#   c2nix = []; # optional, cabal2nix options
#   flags = []; # optional, configure flags
#
#   # When build == "copy"
#   # Copies the bin, etc directories from the source
#   # See copyRepo function in nixpack.lib
#   binFiles = []; # optional, paths of files to put in bin dir
#   tagLocal = true; # optional,  symlink the bins in ~/.nix-profile/local
#  };

# Use set overlay for optional fields
  git = url: rev:
    { type = "git";
      inherit url rev;
    };

  # suggested convenience functions
  #gitcp = url: rev: git url rev // { build = "copy"; };
  #gitimp = url: rev: git url rev // { build = "import"; };

# Why do we have a "githost" type, why "git" is not enough? With githost we can
# compose the URL using different parts, this allows us to overlay the protocol
# part of the URL https or ssh without having to parse the URL. Also, if
# required later, the URL can be constructed in a host specific way using the
# owner and repo info. Another reason is that scripts like "list-sources" can
# work on a per-host basis for checking the latest commit-ids automatically.

# Example:
# Where the field is optional default values are filled.
#  streamly = {
#   type = "githost";
#
#   # ssh (git@github.com/) or https (https://github.com/)
#   host = "github.com";
#   owner = "composewell";
#   repo = "streamly";
#   https = true; # optional, when false ssh is used
#   user = "git" # optional, ssh user
#   # if specified uses localPrefix/repo as the git repo instead of
#   # fetching from the remote host.
#   localPrefix = null # optional
#
#   # Remaining options same as git.
#  };

  gh = owner: repo: rev:
    { type = "githost";
      host = "github.com";
      inherit owner repo rev;
    };

  # Convenience function example:
  # ghcw = repo: rev: gh "composewell" repo rev

  mkGithubURL = owner: repo:
    "git@github.com:${owner}/${repo}.git";

  mkGithubHttpsURL = owner: repo:
    "https://github.com/${owner}/${repo}.git";

  githubAll = owner: repo: rev: branch: subdir: c2nix: flags:
    gh owner repo rev // { inherit branch subdir c2nix flags; };

  defaultBranch = "master";

  githubBranchOpts = owner: repo: rev: branch: c2nix: flags:
    githubAll owner repo rev branch "" c2nix flags;

  githubOpts = owner: repo: rev: c2nix: flags:
    githubBranchOpts owner repo rev defaultBranch c2nix flags;

  githubBranch = owner: repo: rev: branch:
    githubBranchOpts owner repo rev branch [] [];

  githubSubdir = owner: repo: rev: subdir:
    githubAll owner repo rev defaultBranch subdir [] [];

  github = owner: repo: rev:
    githubOpts owner repo rev [] [];

# Example:
#  some-utils = {
#   type = "local";
#   path = /x/y; # local file system path
#   # Rest of the options same as type = "git".
#  };

  # Use set overlay for optional fields
  local = path: { type = "local"; inherit path; };

  # recommended convenience function
  #localcp = path: local path // { build = "copy"; };

  localOpts = path: c2nix: flags:
    local path // { inherit c2nix; inherit flags; };

in
{
  inherit hackage;
  inherit git;
  inherit gh;
  inherit local;
  inherit defaultBranch;

  # To be removed
  inherit hackageProf;
  inherit mkGithubURL;
  inherit mkGithubHttpsURL;

  inherit githubBranchOpts;
  inherit githubOpts;
  inherit githubBranch;
  inherit githubSubdir;
  inherit github;
  inherit localOpts;
}
