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
        users = [
          {
            username = "nikodem";
            workDir = "~/tmp/";
            groups = [ "wheel" "networkmanager" ];
            extraPkgs = [ "openjdk17" ];
          }
          {
            username = "work";
            workDir = "~/projects/";
            groups = [ "networkmanager" ];
            extraPkgs = [ "nodejs_16" "nodePackages_latest.firebase-tools" ];
          }
          {
            username = "school";
            workDir = "~/projects/";
            groups = [ "networkmanager" ];
            extraPkgs = [ "openjdk17" "nodejs" ];
          }
        ];
      }
    ];

    mkHMUser = { system, username, extraPkgs, workDir, ... }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit inputs outputs;
          inherit username extraPkgs workDir;
        };
        modules = [
          hyprland.homeManagerModules.default
          ./home-manager
        ];
      };
  in rec {
    packages = forAllSystems (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in import ./pkgs { inherit pkgs; }
    );

    overlays = import ./overlays { inherit inputs; };
    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;

    nixosConfigurations = builtins.listToAttrs ( builtins.map ( host: {
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
    }) hosts );

    homeConfigurations = builtins.listToAttrs (
      nixpkgs.lib.lists.flatten (
        builtins.map ( host:
          builtins.map ( user: {
            name = "${user.username}@${host.hostname}";
            value = mkHMUser {
              inherit (user) username extraPkgs workDir;
              inherit (host) system;
            };
          }) host.users
        ) hosts
      )
    );
  };
}
