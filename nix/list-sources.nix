{ sources }:
let
  nixpack = import ./default.nix;
  pkgs = import <nixpkgs> {};
  srcs = import sources { inherit nixpack; };

  # merge layer sets if they exist
  packages = pkgs.lib.attrsets.mergeAttrsList (
    (if srcs ? layers then srcs.layers else [])
    # There is no "other" attribute as of now but we can keep this for
    # expressing dummy dependencies.
    ++ [ (if srcs ? other then srcs.other else {}) ]
  );

  text = builtins.concatStringsSep "\n"
  (builtins.filter (s: s != "")
    (pkgs.lib.mapAttrsToList
      (name: spec:
        let branch = spec.branch or nixpack.mkSources.defaultBranch;
        in
        # XXX print host name as well
        # XXX print the url instead of owner/repo etc.
        # The shell script currently handles only github for checking the
        # latest commit, local sources or other rnadom sources are not handled.
        # We can tag non-github sources and print those for manual checking.
        if spec.type == "githost" then
          if spec.host == "github.com" then
            "${name},${spec.owner},${spec.repo},${branch},${spec.rev}"
          else ""
        #else if spec.type == "git" then
        #  "${name},${spec.url},"-",${branch},${spec.rev}"
        else ""
      )
      packages));
in
pkgs.stdenv.mkDerivation {
  name = "list-sources";
  buildCommand = ''
    echo "Generating list of all github sources..."
    echo "${text}" > $out
    echo "Generated: $out"
  '';
}
