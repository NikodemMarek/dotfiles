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
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      inherit (self) outputs;

      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
      ];

      users = {
        nikodem = {
            username = "nikodem";
            groups = [ "wheel" "networkmanager" "docker" ];
        };
        school = {
            username = "school";
            groups = [ "networkmanager" ];
        };
        fun = {
            username = "fun";
            groups = [ "wheel" "networkmanager" "docker" ];
        };
        rustchain = {
            username = "rustchain";
            groups = [ "networkmanager" "docker" ];
        };
      };

      hosts = [
        {
          hostname = "laptop";
          system = "x86_64-linux";
          settings = {
            device = "laptop";
            resolution = { width = 1920; height = 1080; };
            bluetooth = true;
            swap = 15;
          };
          users = with users; [
            nikodem
            school
            rustchain
            fun
          ];
        }
        {
          hostname = "desktop";
          system = "x86_64-linux";
          settings = {
            device = "desktop";
            resolution = { width = 2560; height = 1440; };
            bluetooth = false;
            swap = 38;
          };
          users = with users; [
            nikodem
            rustchain
            fun
            school
          ];
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
        (host: {
          name = host.hostname;
          value = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs outputs;
              inherit (host) hostname users;
            };
            modules = [
              ./host
              ./host/${host.hostname}
            ];
          };
        })
        hosts);

      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.lists.flatten (
          builtins.map
            (host:
              builtins.map
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

                        settings = user-config.settings // host.settings;
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
                host.users
            )
            hosts
        )
      );
    };
}

