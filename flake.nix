{
  description = "An empty flake template that you can adapt to your own environment";

  # Flake inputs
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0"; # Stable Nixpkgs
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz"; # FlakeHub
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*"; # Determinate Flakes
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Flake outputs
  outputs = {
    self,
    nixpkgs,
    disko,
    ...
  } @ inputs: let
    # The systems supported for this flake's outputs
    supportedSystems = [
      "x86_64-linux" # 64-bit Intel/AMD Linux
      "aarch64-linux" # 64-bit ARM Linux
      "x86_64-darwin" # 64-bit Intel macOS
      "aarch64-darwin" # 64-bit ARM macOS
    ];

    # Helper for providing system-specific attributes
    forEachSupportedSystem = f:
      inputs.nixpkgs.lib.genAttrs supportedSystems (
        system:
          f {
            # Provides a system-specific, configured Nixpkgs
            pkgs = import inputs.nixpkgs {
              inherit system;
              # Enable using unfree packages
              config.allowUnfree = true;
            };
          }
      );
    system = "aarch64-linux";
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        inputs.determinate.nixosModules.default
        inputs.disko.nixosModules.disko
        ./disko-config.nix
        {
          # Basic hostname
          networking.hostName = "mixos";

          nixpkgs.config = {
            allowUnfree = true;
            allowUnsupportedSystem = true;
          };

          fonts.packages = with nixpkgs.legacyPackages.${system}; [dejavu_fonts noto-fonts];

          # Enable SSH
          services.openssh.enable = true;

          # X11 and Display Manager
          services.xserver = {
            enable = true;
            windowManager.dwm.enable = true;
          };

          # ly display manager
          services.displayManager.ly.enable = true;

          # VMware guest optimizations for M1 Mac
          virtualisation.vmware.guest.enable = true;

          # Hardware acceleration and graphics
          hardware.graphics.enable = true;

          users.users.conner = {
            isNormalUser = true;
            extraGroups = ["wheel"]; # sudo access
            password = "changeme"; # set via `passwd` after first login

            shell = nixpkgs.legacyPackages.${system}.zsh;
          };

          networking.interfaces.ens160.useDHCP = true;
          # Allow sudo without password for wheel
          security.sudo.wheelNeedsPassword = false;

          # Set your timezone and locale
          time.timeZone = "America/Chicago";
          i18n.defaultLocale = "en_US.UTF-8";

          # Enable networking with NetworkManager
          networking.networkmanager.enable = true;

          programs = {
            zsh.enable = true;
            direnv = {
              enable = true;
              nix-direnv.enable = true;
            };
          };

          # Basic packages
          environment.systemPackages = with nixpkgs.legacyPackages.${system}; [
            vim
            git
            curl
            neovim
            wget
            zellij
            zinit
            ripgrep
            fd
            bat
            htop
            lsof
            tree
            gnumake
            gcc
            jq
            zsh
            gnumake
            sad
            bun
            openssl
            gh
            lua-language-server
            inputs.fh.packages.${system}.fh
            # X11 and desktop utilities
            xorg.xrandr
            xorg.xsetroot
            dmenu
            st
            firefox
            alacritty
            feh
            rofi
            # VMware tools
            open-vm-tools
          ];

          # Bootloader (for ARM boards you may need to tweak)
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          # Required for flakes
          nix.settings = {
            lazy-trees = true;
            experimental-features = ["nix-command" "flakes"];
            trusted-users = ["root" "connerohnesorge" "@wheel"];
            allowed-users = ["@wheel" "@builders" "connerohnesorge" "root"];
          };

          # System state version
          system.stateVersion = "25.05";
        }
      ];
    };
    # Development environments output by this flake
    devShells = forEachSupportedSystem (
      {pkgs}: {
        # Run `nix develop` to activate this environment or `direnv allow` if you have direnv installed
        default = pkgs.mkShell {
          # The Nix packages provided in the environment
          packages = with pkgs; [
            alejandra
            nixd
          ];

          # Set any environment variables for your development environment
          env = {};

          # Add any shell logic you want executed when the environment is activated
          shellHook = "";
        };
      }
    );
  };
}
