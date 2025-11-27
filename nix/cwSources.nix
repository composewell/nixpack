with import ./mkSources.nix;

let
  cw = "composewell";
  master = "master";

  composewellBranchOpts = repo: rev: branch: c2nix: flags:
    githubBranchOpts cw repo rev branch c2nix flags;
  composewellOpts = repo: rev: c2nix: flags:
    composewellBranchOpts repo rev master c2nix flags;
  composewellBranch = repo: rev: branch:
    composewellBranchOpts repo rev branch [] [];
  composewellSubdir = repo: rev: subdir:
    githubSubdir cw repo rev subdir;
  composewell = repo: rev:
    composewellOpts repo rev [] [];
in
{
  inherit composewellBranchOpts;
  inherit composewellOpts;
  inherit composewellBranch;
  inherit composewellSubdir;
  inherit composewell;
}
