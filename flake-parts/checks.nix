{
  inputs,
  lib,
  self,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
      clientVariant = if system == "aarch64-linux" then "source" else "prebuilt";
      mkHome =
        extraModule:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeModules.t3code
            {
              home = {
                username = "test";
                inherit homeDirectory;
                stateVersion = "25.05";
              };
            }
            extraModule
          ];
        };
      matching = mkHome {
        programs.t3code = {
          enable = true;
          packageVariant = clientVariant;
        };
        services.t3code.enable = true;
      };
      mismatched = mkHome {
        programs.t3code = {
          enable = true;
          package = self.packages.${system}.t3code-source;
        };
        services.t3code = {
          enable = true;
          package = self.packages.${system}.t3code-server-nightly-source;
        };
      };
      matchingAssertionsPass = lib.all (entry: entry.assertion) matching.config.assertions;
      opencodeV2 = mkHome {
        programs.t3code = {
          enable = true;
          package = self.packages.${system}.t3code-opencode-v2;
        };
        services.t3code = {
          enable = true;
          package = self.packages.${system}.t3code-server-opencode-v2;
          providerPackages = [ self.packages.${system}.opencode-v2 ];
        };
      };
      opencodeV2Service =
        if pkgs.stdenv.hostPlatform.isDarwin then
          opencodeV2.config.launchd.agents.t3code.config
        else
          opencodeV2.config.systemd.user.services.t3code.Service;
      opencodeV2Environment =
        if pkgs.stdenv.hostPlatform.isDarwin then
          opencodeV2Service.EnvironmentVariables
        else
          lib.listToAttrs (
            map (
              entry:
              let
                plainEntry = builtins.unsafeDiscardStringContext entry;
                parts = lib.splitString "=" plainEntry;
              in
              lib.nameValuePair (lib.head parts) (lib.concatStringsSep "=" (lib.tail parts))
            ) opencodeV2Service.Environment
          );
      opencodeV2Matches =
        lib.getVersion opencodeV2.config.programs.t3code.package == "0.0.42-opencode-v2"
        && lib.getVersion opencodeV2.config.services.t3code.package == "0.0.42-opencode-v2"
        && lib.hasInfix (builtins.unsafeDiscardStringContext "${self.packages.${system}.opencode-v2}/bin") (
          builtins.unsafeDiscardStringContext opencodeV2Environment.PATH
        )
        && opencodeV2Environment.T3CODE_DISABLE_AUTO_UPDATE == "1";
      mismatchRejected = !(builtins.tryEval mismatched.activationPackage.drvPath).success;
      serviceDefined =
        if pkgs.stdenv.hostPlatform.isDarwin then
          matching.config.launchd.agents ? t3code
        else
          matching.config.systemd.user.services ? t3code;
      unsupportedArmPrebuiltRejected =
        if system != "aarch64-linux" then
          true
        else
          let
            unsupported = mkHome { programs.t3code.enable = true; };
          in
          !(builtins.tryEval unsupported.activationPackage.drvPath).success;
      customPackages = self.lib.mkSourcePackages pkgs {
        src = ../.;
        version = "0.0.0-custom-check";
        pnpmHash = lib.fakeHash;
        cargoHash = lib.fakeHash;
        pnpmVersion = "11.10.0";
        electronVersion = "44.1.0";
      };
      customPackagesEvaluate = builtins.deepSeq [
        customPackages.client.drvPath
        customPackages.client.resourceMonitor.drvPath
        customPackages.server.drvPath
        customPackages.server.resourceMonitor.drvPath
      ] true;
    in
    {
      checks.home-module =
        assert matchingAssertionsPass;
        assert mismatchRejected;
        assert serviceDefined;
        assert unsupportedArmPrebuiltRejected;
        assert customPackagesEvaluate;
        assert opencodeV2Matches;
        pkgs.runCommand "t3code-home-module-evaluation" { } "touch $out";
    };
}
