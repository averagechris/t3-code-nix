# --- flake-parts/pkgs/default.nix
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      t3codePackages = import ../../packages { inherit pkgs; };
      opencodeNodeModules = pkgs.callPackage "${inputs.opencode-v2-src}/nix/node_modules.nix" (
        {
          rev = inputs.opencode-v2-src.shortRev;
        }
        // pkgs.lib.optionalAttrs (system == "aarch64-darwin") {
          # Upstream v2.0.8 carries a stale fixed-output hash for this platform.
          hash = "sha256-lthMTio2qNy+H2tL9cAPmqC41O+wdSADI61cnW4dIb0=";
        }
      );
      opencodeV2 = pkgs.callPackage "${inputs.opencode-v2-src}/nix/opencode.nix" {
        node_modules = opencodeNodeModules;
      };
    in
    {
      formatter = pkgs.nixfmt;
      packages = t3codePackages // {
        opencode-v2 = opencodeV2;
      };
    };
}
