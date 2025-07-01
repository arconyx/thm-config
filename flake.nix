{
  description = "NixOS config for THM servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.2-1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # matrix stuff
    # conduwuit = {
    #   url = "github:matrix-construct/tuwunel";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # ooye = {
    #   url = "git+https://cgit.rory.gay/nix/OOYE-module.git";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
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
      home-manager,
      lix-module,
      pre-commit-hooks,
      # ooye,
      # conduwuit,
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
    in
    {
      checks = forAllSystems (system: {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = self;
          hooks = {
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

      # TODO: generalise
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;

      nixosConfigurations.hive = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";

        specialArgs = {
          # Should probably use an overlay or something to add these to nixpkgs
          # ooyepkgs = ooye.packages.${system};
          # conduwuitpkgs = conduwuit.packages.${system};
          modpack = thm-modpack.packages.${system}.default;
          inherit revision;
        };

        modules = [
          ./common/common.nix
          ./hosts/hive/configuration.nix

          lix-module.nixosModules.default
          # ooye.modules.default
          tsnsrv.nixosModules.default

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.backupFileExtension = "backup";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.arc = import ./home/arc.nix;
            home-manager.users.fishynz = import ./home/common.nix;

            # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix
            # home-manager.extraSpecialArgs = specialArgs;
          }

          nix-minecraft.nixosModules.minecraft-servers
          {
            nixpkgs.overlays = [ nix-minecraft.overlay ];
          }
        ];
      };
    };
}
