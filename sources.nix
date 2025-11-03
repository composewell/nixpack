{nixpack}:
# Package sources to override the nixpkgs package set.

with nixpack.mkSources;
{

layers = [
# First layer, overrides the nix provided packages.
{
  #streamly = hackage "0.11.0" "sha256-JMZAwJHqmDxN/CCDFhfuv77xmAx1JVhvYFDxMKyQoGk=";
  #unicode-data = hackageProf "0.6.0" "sha256-gW1E5VFwZcUX5v1dvi3INDDqUuwCcOTjCR5+lOW3Obc==";
  # Custom definition example::
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
}

# Second layer, overrides the above layer
{
  #bench-show = composewellBranchFlags "bench-show"
  #               "dc07910c4442bbaf22a8093bf6ada7fee6a57322"
  #               "remove-deps-for-nix"
  #               [ "--flags no-charts" ];

}

# Can add more layers here.

];

# Upper bounds of the dependencies of these packages are relaxed.
# jailbreaks = [ "streamly-core" ];

}
