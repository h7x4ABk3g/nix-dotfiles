{ pkgs, config, inputs, secrets, ... }:
let
  inherit (pkgs) lib;
  # inherit (specialArgs) machineVars;
  # inherit (config) machineVars;
  # has_graphics = !config.machineVars.headless;
in {
  time.timeZone = "Europe/Oslo";

  i18n.defaultLocale = "en_US.UTF-8";

  nixpkgs.config = {
    allowUnfree = true;
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  networking = {
    useDHCP = false;
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
      builders-use-substitutes = true
    '';

    distributedBuilds = (config.networking.hostName != "Tsuki");
    binaryCaches = [
      "https://cache.nixos.org/"
    ];

    buildMachines = [
      {
        hostName = "Tsuki";
        system = "x86_64-linux";
        maxJobs = 1;
        speedFactor = 3;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-paralell"
          "kvm"
        ];
        mandatoryFeatures = [];
      }
    ];
  };

  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    systemPackages = with pkgs; ([
      wget
    ] ++ (lib.optionals (!config.machineVars.headless) [
      haskellPackages.xmobar
    ]));

    shells = with pkgs; [
      bashInteractive
      zsh
      dash
    ];

    etc = {
      # TODO: move this out of etc, and reference it directly in sudo config.
      sudoLecture = {
        target = "sudo.lecture";
        text = lib.termColors.front.red "Be careful or something, idk...\n";
      };

      "resolv.conf".source = let
        inherit (lib.strings) concatStringsSep;
        inherit (pkgs) writeText;
      in writeText "resolv.conf" ''
        ${concatStringsSep "\n" (map (ns: "nameserver ${ns}") config.networking.nameservers)}
        options edns0
      '';

      currentSystemPackages = {
        target = "current-system-packages";
        text = let
          inherit (lib.strings) concatStringsSep;
          inherit (lib.lists) sort;
          inherit (lib.trivial) lessThan;
          packages = map (p: "${p.name}") config.environment.systemPackages;
          sortedUnique = sort lessThan (lib.unique packages);
        in concatStringsSep "\n" sortedUnique;
      };
    };
  };

  fonts = {
    enableDefaultFonts = true;

    fontDir.enable = true;

    fonts = with pkgs; [
      cm_unicode
      dejavu_fonts
      fira-code
      fira-code-symbols
      powerline-fonts
      iosevka
      symbola
      corefonts
      ipaexfont
      ipafont
      liberation_ttf
      migmix
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji
      open-sans
      source-han-sans
      source-sans
      ubuntu_font_family
      victor-mono
      (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
      inputs.fonts
    ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Droid Sans Serif" "Ubuntu" ];
        sansSerif = [ "Droid Sans" "Ubuntu" ];
        monospace = [ "Fira Code" "Ubuntu" ];
        emoji = [ "Noto Sans Emoji" ];
      };
    };
  };

  users.users.h7x4 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "audio"
      "video"
      "disk"
      "libvirtd"
      "input"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs; inherit secrets; };

    # TODO: figure out why specialArgs isn't accessible from the root home file.
    users.h7x4 = import ../home.nix {
      inherit pkgs;
      inherit inputs;
      inherit config;
    };
  };

  services = {
    tumbler.enable = !config.machineVars.headless;
    gnome.gnome-keyring.enable = !config.machineVars.headless;

    openssh = {
      # enable = true;
      passwordAuthentication = false;
      kbdInteractiveAuthentication = false;
      permitRootLogin = "no";
    };

    dbus = {
      # enable = !machineVars.headless;
      packages = with pkgs; [
        gcr
        dconf
      ];
    };

    xserver = {
      # TODO: What is going on here? 
      #       For some reason, this leads to infinite recursion.
      #       This needs to be fixed!
      #       Same with `displayManager.lightdm.enable`
      #       options are defined in each hosts config file for the time being.
      #
      #       I have a hypothesis that there are some asserts within xserver that
      #       makes it so that other software can not be activated at the same time
      #       and that those asserts triggers some kind of evaluation chain that
      #       recurses infinitely.
      # enable = true;
      layout = "us";
      xkbOptions = "caps:escape";

      libinput = {
        enable = true;
        touchpad.disableWhileTyping = true;
      };

      desktopManager = {
        xterm.enable = false;
        xfce.enable = !config.machineVars.headless;
      };

      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
      };

      # displayManager.startx.enable = true;
      # displayManager.gdm.enable = true;
      # displayManager.lightdm.enable = true;
      displayManager.defaultSession = "none+xmonad";
    };

  };

  programs = {
    dconf.enable = !config.machineVars.headless;
    git.enable = true;
    light.enable = !config.machineVars.headless;
    npm.enable = true;
    tmux.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      configure = {
        packages.myVimPackage = with pkgs.vimPlugins; {
          start = [
            direnv-vim
            vim-nix
            vim-polyglot
          ];

          opt = [
            vim-monokai
          ];
        };

        customRC = ''
          set number relativenumber
          set undofile
          set undodir=~/.cache/vim/undodir

          packadd! vim-monokai
          colorscheme monokai
        '';
      };
    };
  };

  environment.shellAliases.fixDisplay = let
    inherit (config.machineVars) screens headless fixDisplayCommand;
    screenToArgs = screen: with screen;
      "--output ${name} --mode ${resolution}"
      + (lib.optionalString (frequency != null) " --rate ${frequency}");
    screenArgs = lib.concatStringsSep " " (lib.mapAttrsToList screenToArgs screens);
  in lib.mkIf (!headless)
    (lib.mkMerge [
      "xrandr ${screenArgs}"
      (lib.mkIf (fixDisplayCommand != null) fixDisplayCommand)
    ]);

  system.extraDependencies =
    lib.optionals (config.machineVars.development) (with pkgs; [
      asciidoc
      asciidoctor
      cabal2nix
      clang
      dart
      dotnet-sdk
      dotnet-sdk_3
      dotnet-sdk_5
      dotnetPackages.Nuget
      elm2nix
      elmPackages.elm
      flutter
      gcc
      ghc
      ghcid
      haskellPackages.Cabal_3_6_3_0
      maven
      nixfmt
      nixpkgs-fmt
      # nixpkgs-hammering
      nodePackages.node2nix
      nodePackages.npm
      nodePackages.sass
      nodePackages.typescript
      nodePackages.yarn
      nodejs
      plantuml
      python3
      rustc
      rustc
      rustup
      sqlcheck
      sqlint
      sqlite
      sqlite-web
    ]);

  sound = {
    enable = !config.machineVars.headless;
    mediaKeys.enable = true;
  };

  hardware.pulseaudio.enable = !config.machineVars.headless;

  security.sudo.extraConfig = ''
    Defaults    lecture = always
    Defaults    lecture_file = /etc/${config.environment.etc.sudoLecture.target}
  '';

  system.stateVersion = "22.05";
}
