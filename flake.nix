{
  description = "system configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, home-manager, hyprland, ... }@inputs:
    let
      inherit (self) outputs;

      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
      ];

      hosts = [
        {
          hostname = "laptop";
          system = "x86_64-linux";
          device = "laptop";
          resolution = { width = 1920; height = 1080; };
          users = [
            {
              username = "nikodem";
              workDir = "~/tmp/";
              groups = [ "wheel" "networkmanager" "docker" ];
              extraPkgs = [ "zip" "unzip" "qutebrowser" "zathura" "typst" "beeper" ];
              programs = [ "firefox" "neovim" "eww" "hypr" ];
              name = "nikodem";
              email = "nikodemmarek11@gmail.com";
            }
            {
              username = "work";
              workDir = "~/projects/";
              groups = [ "networkmanager" ];
              extraPkgs = [ "nodejs_16" "firebase-tools" "zola" ];
              programs = [ "firefox" "neovim" "eww" "hypr" ];
              name = "nikodem";
              email = "nikodemmarek11@gmail.com";
            }
            {
              username = "school";
              workDir = "~/projects/";
              groups = [ "networkmanager" ];
              extraPkgs = [ "openjdk17" "nodejs" "maven" "qutebrowser" ];
              programs = [ "firefox" "neovim" "eww" "hypr" ];
              name = "nikodem";
              email = "nikodemmarek11@gmail.com";
            }
            {
              username = "fun";
              workDir = "~/tmp/";
              groups = [ "wheel" "networkmanager" "docker" ];
              extraPkgs = [ "qutebrowser" "beeper" "steam" ];
              programs = [ "firefox" "eww" "hypr" ];
              name = "nikodem";
              email = "nikodemmarek11@gmail.com";
            }
          ];
        }
      ];

      mkHMUser =
        { system
        , device
        , resolution
        , username
        , extraPkgs
        , programs
        , workDir
        , name
        , email
        , ...
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit username extraPkgs programs workDir device resolution name email;
          };
          modules = [
            hyprland.homeManagerModules.default
            ./home-manager
          ];
        };
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
            ];
          };
        })
        hosts);

      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.lists.flatten (
          builtins.map
            (host:
              builtins.map
                (user: {
                  name = "${user.username}@${host.hostname}";
                  value = mkHMUser {
                    inherit (host) system;
                    inherit (host) device resolution;
                    inherit (user) username extraPkgs programs workDir name email;
                  };
                })
                host.users
            )
            hosts
        )
      );
    };
}
