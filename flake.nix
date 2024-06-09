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
      {
        name = "laptop";
        users = ["nikodem" "fun"];
      }
      {
        name = "desktop";
        users = ["nikodem" "fun"];
      }
    ];

    utils = import ./utils;
    pkgsFor = nixpkgs.lib.genAttrs ["x86_64-linux"] (system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [inputs.wired.overlays.default];
      });

    mkhost = host:
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;

          hostname = host;
        };
        modules = [
          ./host/${host}
          ./host
        ];
      };
    mkhome = host: user:
      home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor."x86_64-linux";
        extraSpecialArgs = {
          inherit inputs outputs;
          inherit utils;

          hostname = host;
          username = user;
        };
        modules = [
          ./host/${host}/users/${user}
          ./home
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
        inherit (host) name;
        value = mkhost host.name;
      })
      hosts);

    homeConfigurations = builtins.listToAttrs (
      nixpkgs.lib.lists.flatten (
        builtins.map (
          host:
            builtins.map
            (user: {
              name = "${user}@${host.name}";
              value = mkhome host.name user;
            })
            host.users
        )
        hosts
      )
    );
  };
}
