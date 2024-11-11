# Nix config
# Kristian Freeman / kristianfreeman.com
# Created 2024-11-08

# Tested with https://determinate.systems installer

# Sources that helped me set this up:
#  - https://davi.sh/blog/2024/01/nix-darwin/
#  - https://nixcademy.com/posts/nix-on-macos/
#  - https://github.com/mirkolenz/nixos/blob/main/system/darwin/settings.nix

{
  description = "Kristian Freeman system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nix-darwin, nixpkgs, nix-homebrew, homebrew-core, homebrew-cask, home-manager }:

  let
    commonHomeConfig = import ./home/common.nix;

    darwinConfiguration = { pkgs, ... }: {
      # Default settings from nix-darwin.
      ###################################
      services.nix-daemon.enable = true;
      nix.settings.experimental-features = "nix-command flakes";
      nix.extraOptions = ''
        extra-platforms = x86_64-darwin aarch64-darwin
      '';
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 5;
      nixpkgs.hostPlatform = "aarch64-darwin";

      users.users.kristian = {
        name = "kristian";
        home = "/Users/kristian";
      };

      # Install homebrew if not yet installed
      nix-homebrew = {
        enable = true;
        enableRosetta = true;
        user = "kristian";

        taps = {
          "homebrew/homebrew-core" = homebrew-core;
          "homebrew/homebrew-cask" = homebrew-cask;
        };
      };

      # Nix packages
      ##############
      environment.systemPackages = [
        pkgs.fzf
        pkgs.jq
        pkgs.mas 
        pkgs.neofetch 
        pkgs.neovim 
        pkgs.nodejs_22
        pkgs.ripgrep
        pkgs.solana-cli 
        pkgs.zellij
        pkgs.zoxide
      ];

      # Homebrew, managed by Nix
      ##########################
      homebrew = {
        enable = true;
        onActivation.cleanup = "uninstall";
        taps = [
          "homebrew/homebrew-core"
          "homebrew/homebrew-cask"
        ];
        brews = [];
        casks = [ 
          "1password" 
          "balenaetcher"
          "boltai"
          "discord"
          "flux"
          "font-atkinson-hyperlegible"
          "font-jetbrains-mono-nerd-font"
          "jordanbaird-ice"
          "karabiner-elements"
          "kitty" 
          "obsidian"
          "plexamp" 
          "raycast"
          "signal"
          "slack"
          "telegram"
        ];
        masApps = {
          Noir = 1592917505;
          OnePasswordExtension = 1569813296;
        };
      };

      # System settings
      #################

      # Enable Touch ID support
      security.pam.enableSudoTouchIdAuth = true;

      # System settings
      system.defaults = {
        loginwindow.LoginwindowText = "REWARD IF LOST: kristian@kristianfreeman.com";
        screencapture.location = "~/Pictures/Screenshots";
        screensaver.askForPasswordDelay = 10;

        # Dock
        dock = {
          autohide = true;
          autohide-time-modifier = 0.1;
          mru-spaces = false;
          show-recents = false;
          static-only = true;
        };

        finder = {
          AppleShowAllExtensions = true;
          FXPreferredViewStyle = "clmv";
        };

        NSGlobalDomain = { 
          # Fix trackpad scroll direction
          "com.apple.swipescrolldirection" = false;
          ApplePressAndHoldEnabled = false;

          InitialKeyRepeat = 10;
          KeyRepeat = 1;
        };
      };
    };

    nixosConfiguration = { config, pkgs, ... }: {
      imports = [
        ./hosts/sauron/hardware-configuration.nix
      ];

      nixpkgs.system = "x86_64-linux";
      users.users.kristian = {
        isNormalUser = true;
        home = "/home/kristian";
        description = "Kristian Freeman";
        extraGroups = [ "wheel" "networkmanager" ];
      };

      networking = {
        hostName = "sauron"; # Define hostname
        networkmanager.enable = true;
      };

      time.timeZone = "America/Chicago";

      i18n = {
        defaultLocale = "en_US.UTF-8";
        extraLocaleSettings = {
          LC_TIME = "en_US.UTF-8";
        };
      };

      services = {
        xserver = {
          enable = true;
          displayManager.lightdm.enable = true;
          desktopManager.xfce.enable = true;
          xkb = { layout = "us"; variant = "colemak"; };
        };
        printing.enable = true;
        pipewire = {
          enable = true;
          alsa.enable = true;
          pulse.enable = true;
        };
        openssh.enable = true;
      };

      environment.systemPackages = with pkgs; [
        fzf vim neovim ripgrep solana-cli zellij zoxide
      ];

      nixpkgs.config = { allowUnfree = true; };
      system.stateVersion = "24.05";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#bilbo
    darwinConfigurations.bilbo = nix-darwin.lib.darwinSystem {
      modules = [
        darwinConfiguration
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.verbose = true;
          home-manager.users.kristian = commonHomeConfig;
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations.bilbo.pkgs;

    nixosConfigurations.sauron = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixosConfiguration
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.kristian = commonHomeConfig;
        }
      ];
    };
  };
}
