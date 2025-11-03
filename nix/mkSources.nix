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
#   type = "github";
#   https = false;
#   owner = "composewell";
#   repo = "streamly";
#   rev = "b469a10f4f7f4d9ebaad828ba008dd7ac6f04849";
#   branch = "custom";
#   subdir = "/core";
#   flags = [];
#  };

  mkGithubURL = owner: repo:
    "git@github.com:${owner}/${repo}.git";

  mkGithubHttpsURL = owner: repo:
    "https://github.com/${owner}/${repo}.git";

  githubAll = owner: repo: rev: branch: subdir: flags: {
    type = "github";
    https = false;
    inherit owner repo rev branch subdir flags;
  };

  master = "master";

  githubBranchFlags = owner: repo: rev: branch: flags:
    githubAll owner repo rev branch "" flags;

  githubFlags = owner: repo: rev: flags:
    githubBranchFlags owner repo rev master flags;

  githubBranch = owner: repo: rev: branch:
    githubBranchFlags owner repo rev branch [];

  githubSubdir = owner: repo: rev: subdir:
    githubAll owner repo rev master subdir [];

  github = owner: repo: rev:
    githubFlags owner repo rev [];

# type: "local"
#   path:
#   subdir:
#   flags:

  localSubdirFlags = path: subdir: flags: {
    type = "local";
    inherit path subdir flags;
  };

  localSubdir = path: subdir:
    localSubdirFlags path subdir [];

  local = path:
    localSubdir path "";

in
{
  inherit hackage;
  inherit hackageProf;
  inherit mkGithubURL;
  inherit mkGithubHttpsURL;
  inherit githubBranchFlags;
  inherit githubFlags;
  inherit githubBranch;
  inherit githubSubdir;
  inherit github;
  inherit localSubdirFlags;
  inherit localSubdir;
  inherit local;
}
