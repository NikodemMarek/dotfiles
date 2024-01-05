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

      users = {
        nikodem = {
          username = "nikodem";
          groups = [ "wheel" "networkmanager" "docker" ];
          programs = [ "firefox" "neovim" "eww" "hypr" "qutebrowser" "zip" "unzip" "zathura" "typst" "beeper" "bottom" ];
          settings = {
            workDir = "~/tmp/";
            name = "nikodem";
            email = "nikodemmarek11@gmail.com";
            eww = {
              shortcuts = [
                [

                  [ "firefox" "" ]
                  [ "qutebrowser" "󰖟" ]
                ]
                [

                  [ "firefox https://mail.google.com/mail/u/0/#inbox" "" ]
                  [ "beeper --default-frame" "󰵅" ]
                ]
              ];
            };
          };
        };
        work = {
          username = "work";
          groups = [ "networkmanager" ];
          programs = [ "firefox" "neovim" "eww" "hypr" "firebase-tools" "zola" ];
          settings = {
            workDir = "~/projects/";
            name = "nikodem";
            email = "nikodemmarek11@gmail.com";
            eww = {
              shortcuts = [
                [

                  [ "firefox" "" ]
                  [ "qutebrowser" "󰖟" ]
                ]
                [

                  [ "firefox https://mail.google.com/mail/u/0/#inbox" "" ]
                  [ "beeper --default-frame" "󰵅" ]
                ]
              ];
            };
          };
        };
        school = {
          username = "school";
          groups = [ "networkmanager" ];
          programs = [ "firefox" "neovim" "eww" "hypr" "openjdk17" "nodejs" "maven" "qutebrowser" "bun" "android-tools" "bruno" ];
          settings = {
            workDir = "~/projects/";
            name = "nikodem";
            email = "nikodemmarek11@gmail.com";
            eww = {
              shortcuts = [
                [

                  [ "firefox" "" ]
                  [ "qutebrowser" "󰖟" ]
                ]
                [

                  [ "firefox https://mail.google.com/mail/u/0/#inbox" "" ]
                  [ "beeper --default-frame" "󰵅" ]
                ]
              ];
            };
          };
        };
        fun = {
          username = "fun";
          groups = [ "wheel" "networkmanager" "docker" ];
          programs = [ "firefox" "eww" "hypr" "qutebrowser" "beeper" "steam" "ferium" "prismlauncher" "lutris" "wine" ];
          settings = {
            workDir = "~/tmp/";
            name = "nikodem";
            email = "nikodemmarek11@gmail.com";
            eww = {
              shortcuts = [
                [
                  [ "firefox" "" ]
                  [ "qutebrowser" "󰖟" ]
                  [ "steam" "st" ]
                ]
                [
                  [ "lutris" "lt" ]
                  [ "beeper --default-frame" "󰵅" ]
                  [ "prismlauncher" "mc" ]
                ]
              ];
            };
          };
        };
        rustchain = {
          username = "rustchain";
          groups = [ "networkmanager" "docker" ];
          programs = [ "firefox" "neovim" "eww" "hypr" "qutebrowser" "rustup" "solana-cli" "yarn" "pkg-config" "gcc" "openssl" ];
          settings = {
            workDir = "~/projects/";
            name = "nikodem";
            email = "nikodemmarekit@gmail.com";
            eww = {
              shortcuts = [
                [
                  [ "firefox" "" ]
                  [ "qutebrowser" "󰖟" ]
                ]
              ];
            };
          };
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
            work
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

      mkHMUser =
        { system
        , hostname
        , username
        , programs
        , settings
        , ...
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit system hostname;
            inherit username programs settings;
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
                (user: {
                  name = "${user.username}@${host.hostname}";
                  value = mkHMUser {
                    inherit (host) system hostname;
                    inherit (user) username programs;
                    settings = {
                      inherit (host.settings) device resolution;
                      inherit (user.settings) workDir name email eww;
                    };
                  };
                })
                host.users
            )
            hosts
        )
      );
    };
}

