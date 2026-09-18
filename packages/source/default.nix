{
  pkgs,
  release,
  source ? null,
}:
let
  inherit (pkgs) lib;
  electronPackage = "electron_${lib.versions.major release.electronVersion}";
  electron =
    pkgs.${electronPackage}
      or (throw "T3 Code ${release.version} requires ${electronPackage}, which is missing from nixpkgs");
  sourceUnwrapped = pkgs.callPackage ./unwrapped.nix { inherit electron release source; };
  resourceMonitor = pkgs.callPackage ./resource-monitor.nix {
    inherit release sourceUnwrapped;
  };
in
{
  client = pkgs.callPackage ./client.nix {
    inherit release resourceMonitor sourceUnwrapped;
  };
  server = pkgs.callPackage ./server.nix {
    inherit release resourceMonitor sourceUnwrapped;
  };
}
