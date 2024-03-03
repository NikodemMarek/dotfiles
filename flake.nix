{
  description = "system configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    sops-nix.url = "github:Mic92/sops-nix";

    nix-colors.url = "github:misterio77/nix-colors";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    anyrun = {
      url = "github:Kirottu/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ld = {
        url = "github:Mic92/nix-ld";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      inherit (self) outputs;

      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
      ];

      hosts = [
        {
          hostname = "laptop";
          system = "x86_64-linux";
        }
        {
          hostname = "desktop";
          system = "x86_64-linux";
        }
      ];

      utils = import ./utils;
    in
    rec {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./pkgs { inherit pkgs; }
      );

      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      nixosConfigurations = builtins.listToAttrs (builtins.map
        (host: let
          system-config = import ./host/${host.hostname};
        in {
          name = host.hostname;
          value = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs outputs;

              inherit (host) hostname;
              inherit (system-config) users settings;
            };
            modules = [
              inputs.nix-ld.nixosModules.nix-ld

              system-config.module
              ./host
            ];
          };
        })
        hosts);

      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.lists.flatten (
          builtins.map
            (host: let
              system-config = import ./host/${host.hostname};
            in builtins.map
                (user: let
                  user-config = import ./home/${user.username}.nix;
                in {
                  name = "${user.username}@${host.hostname}";
                  value = home-manager.lib.homeManagerConfiguration {
                      pkgs = nixpkgs.legacyPackages.${host.system};
                      extraSpecialArgs = {
                        inherit inputs outputs;
                        inherit (inputs) nix-colors;
                        inherit utils;

                        inherit (host) system hostname;
                        inherit (user) username groups;

                        settings = system-config.settings // user-config.settings;
                      };
                      modules = [
                        inputs.sops-nix.homeManagerModules.sops
                        inputs.nixvim.homeManagerModules.nixvim
                        inputs.anyrun.homeManagerModules.anyrun

                        user-config.module
                        ./home
                      ];
                    };
                })
                system-config.users
            )
            hosts
        )
      );
    };
}

