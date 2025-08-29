{
  description = "NixOS config for THM servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    core = {
      url = "github:arconyx/core";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tsnsrv = {
      url = "github:boinkor-net/tsnsrv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    thm-modpack = {
      url = "github:arconyx/thm-modpack";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      core,
      pre-commit-hooks,
      tsnsrv,
      nix-minecraft,
      thm-modpack,
      ...
    }:
    let
      revision = self.shortRev or self.dirtyShortRev or self.lastModified or "unknown";
      supportedSystems = [
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      baseModules = [ core.nixosModules.default ];
    in
    {
      checks = forAllSystems (system: {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = self;
          hooks = {
            deadnix = {
              enable = true;
              settings.noLambdaArg = true;
            };
            nixfmt-rfc-style.enable = true;
            shellcheck.enable = true;
            ripsecrets.enable = true;
          };
        };
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      nixosConfigurations.hive = nixpkgs.lib.nixosSystem {

        specialArgs = {
          inherit thm-modpack;
          inherit revision;
        };

        modules = baseModules ++ [
          ./hosts/hive
          core.nixosModules.default
          tsnsrv.nixosModules.default
          nix-minecraft.nixosModules.minecraft-servers
          {
            nixpkgs.overlays = [ nix-minecraft.overlay ];
          }
        ];
      };
    };
}
