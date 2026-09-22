# --- flake-parts/pkgs/default.nix
{ inputs, self, ... }:
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
      t3codeOpencodeV2 = self.lib.mkSourcePackages pkgs {
        src = inputs.t3code-opencode-v2-src;
        version = "0.0.42-opencode-v2";
        pnpmHash = "sha256-vE1+H8TG8MG+1HVvc9RTWp3Y+54rQurbQwoGAY/9nEo=";
        cargoHash = "sha256-5cmG2daM1bVOA23gjjoalbx0fEL1hmqV6WZov0sUZp8=";
        pnpmVersion = "11.10.0";
        electronVersion = "44.4.2";
      };
    in
    {
      formatter = pkgs.nixfmt;
      packages = t3codePackages // {
        opencode-v2 = opencodeV2;
        t3code-opencode-v2 = t3codeOpencodeV2.client;
        t3code-server-opencode-v2 = t3codeOpencodeV2.server;
      };
    };
}
