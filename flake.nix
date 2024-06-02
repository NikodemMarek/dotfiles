{
  description = "system configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    stylix.url = "github:danth/stylix";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    walker.url = "github:abenz1267/walker";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wired.url = "github:Toqozz/wired-notify";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;

    forAllSystems = nixpkgs.lib.genAttrs [
      "x86_64-linux"
    ];

    hosts = [
      "laptop"
      "desktop"
    ];

    utils = import ./utils;
    pkgsFor = nixpkgs.lib.genAttrs ["x86_64-linux"] (system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [inputs.wired.overlays.default];
      });

    mkhost = hostname: let
      system-config = import ./host/${hostname};
    in
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;

          inherit hostname;
          inherit (system-config) users settings;
        };
        modules = [
          inputs.sops-nix.nixosModules.sops
          inputs.disko.nixosModules.disko
          inputs.impermanence.nixosModules.impermanence
          inputs.stylix.nixosModules.stylix
          inputs.nix-ld.nixosModules.nix-ld

          system-config.module
          ./host
          ./disk-config.nix
        ];
      };
  in {
    packages = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        import ./pkgs {inherit pkgs;}
    );

    overlays = import ./overlays {inherit inputs;};

    nixosConfigurations = builtins.listToAttrs (builtins.map
      (host: {
        name = host;
        value = mkhost host;
      })
      hosts);

    homeConfigurations = builtins.listToAttrs (
      nixpkgs.lib.lists.flatten (
        builtins.map
        (
          hostname: let
            system-config = import ./host/${hostname};
          in
            builtins.map
            (user: let
              user-config = import ./home/${user.username}.nix;
            in {
              name = "${user.username}@${hostname}";
              value = home-manager.lib.homeManagerConfiguration {
                pkgs = pkgsFor.${system-config.settings.system};
                extraSpecialArgs = {
                  inherit inputs outputs;
                  inherit utils;

                  inherit hostname;
                  inherit (user) username groups;
                  inherit (system-config.settings) system;

                  settings = system-config.settings // user-config.settings;
                };
                modules = [
                  inputs.sops-nix.homeManagerModules.sops
                  inputs.stylix.homeManagerModules.stylix
                  inputs.nixvim.homeManagerModules.nixvim
                  inputs.walker.homeManagerModules.walker
                  inputs.wired.homeManagerModules.default

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
