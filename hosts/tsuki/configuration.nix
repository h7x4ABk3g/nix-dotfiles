{
  imports = [
    ./hardware-configuration.nix

    # ./services/calibre.nix
    # ./services/dokuwiki.nix
    ./services/gitea
    # ./services/gitlab
    ./services/grafana.nix
    ./services/hydra.nix
    ./services/jitsi.nix
    # ./services/keycloak.nix
    # ./services/libvirt.nix
    ./services/matrix
    ./services/nginx.nix
    # ./services/openldap.nix
    # ./services/openvpn.nix
    ./services/plex.nix
    ./services/postgres.nix
    ./services/samba.nix
    ./services/searx.nix
    # ./services/syncthing.nix
    ./services/vscode-server.nix
  ];

  # TODO: See ../common.nix
  services.xserver.enable = false;
  services.xserver.displayManager.lightdm.enable = false;

  machineVars = {
    headless = true;
    dataDrives = let 
      momiji = "/data2";
    in {
      drives = {
        cirno = "/data";
        inherit momiji;
      };
      default = momiji;
    };
  };

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # security.pam.services.login.unixAuth = true;

  boot.loader = {
    grub = {
      enable = true;
      version = 2;
      efiSupport = true;
      fsIdentifier = "label";
      device = "nodev";
      efiInstallAsRemovable = true;
    };
    # efi.efiSysMountPoint = "/boot/efi";
    # efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "Tsuki";
    networkmanager.enable = true;
    interfaces.ens18.useDHCP = true;
    firewall.enable=true;
  };

  services = {
    openssh.enable = true;
    printing.enable = true;
    cron = {
      enable = true;
      systemCronJobs = [
    #     "*/5 * * * *      root    date >> /tmp/cron.log"
      ];
    };
  };

  users.groups.media = {};

  users.users = {
    h7x4.extraGroups = [ "media" ];
    media = {
      isSystemUser = true;
      group = "media";
    };
  };

  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };
}
