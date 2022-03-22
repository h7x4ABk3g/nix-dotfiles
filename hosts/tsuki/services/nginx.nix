{ pkgs, config, secrets, inputs, ... }:
  let
    # TODO: fix lib
    lib = pkgs.lib;
      
    inherit (secrets) ips ports;

    s = toString;
  in
{

  security.acme = {
    email = "h7x4abk3g@protonmail.com";
    acceptTerms = true;
  };

  services.nginx = let
    generateServerAliases =
      domains: subdomains:
      lib.lists.flatten (map (s: map (d: "${s}.${d}") domains) subdomains);
  in {
    enable = true;
    
    statusPage = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = let
      inherit (lib.attrsets) nameValuePair listToAttrs recursiveUpdate;
      inherit (lib.lists) head drop;
      inherit (secrets) domains keys;

      makeHost =
        subdomains: extraSettings:
        nameValuePair "${head subdomains}.${head domains}" (recursiveUpdate {
          serverAliases = drop 1 (generateServerAliases domains subdomains);
          forceSSL = true;
          sslCertificate = keys.certificates.server.crt;
          sslCertificateKey = keys.certificates.server.key;
        } extraSettings);

      makeACMEHost =
        subdomains: extraSettings:
        nameValuePair "${head subdomains}.${head domains}" (recursiveUpdate {
          serverAliases = drop 1 (generateServerAliases domains subdomains);
          enableACME = true;
          forceSSL = true;
        } extraSettings);
      
      makeClientCertHost =
        subdomains: extraSettings:
        nameValuePair "${head subdomains}.${head domains}" (recursiveUpdate {
          serverAliases = drop 1 (generateServerAliases domains subdomains);
          enableACME = true;
          forceSSL = true;
          extraConfig = ''
            ssl_client_certificate ${secrets.keys.certificates.CA.crt};
            ssl_verify_client optional;
          '';
          locations."/".extraConfig = ''
            if ($ssl_client_verify != SUCCESS) {
              return 403;
            } 
          '';
        } extraSettings);

      makeProxy = 
        subdomains: url: extraSettings:
        makeHost subdomains (recursiveUpdate { locations."/".proxyPass = url; } extraSettings);

      makeACMEProxy = 
        subdomains: url: extraSettings:
        makeACMEHost subdomains (recursiveUpdate { locations."/".proxyPass = url; } extraSettings);

      makeClientCertProxy = 
        subdomains: url: extraSettings:
        makeClientCertHost subdomains (recursiveUpdate { locations."/".proxyPass = url; } extraSettings);

    in (listToAttrs [
      # (makeACMEProxy ["gitlab"] "http://unix:/run/gitlab/gitlab-workhorse.socket" {})
      (makeACMEProxy ["plex"] "http://localhost:${s ports.plex}" {})
      (makeACMEHost ["www"] { root = "${inputs.website.defaultPackage.${pkgs.system}}/"; })
      (makeACMEProxy ["matrix"] "http://localhost:${s ports.matrix.listener}" {})
      (makeACMEProxy ["git"] "http://localhost:${s ports.gitea}" {})
      (makeClientCertHost ["cache"] { root = "/var/lib/nix-cache"; })
      (makeClientCertProxy ["px1"] "https://${ips.px1}:${s ports.proxmox}" {
          locations."/".proxyWebsockets = true;
      })
      (makeClientCertProxy ["idrac"] "https://${ips.idrac}" {})
      (makeClientCertProxy ["searx"] "http://localhost:${s ports.searx}" {})
      (makeACMEProxy ["dyn"] "http://${ips.crafty}:${s ports.dynmap}" {
        basicAuthFile = keys.htpasswds.default;
      })
      (makeClientCertProxy ["log"] "http://localhost:${s ports.grafana}" {
        locations."/".proxyWebsockets = true;
      })
      # (makeProxy ["wiki"] "" {})
      # (makeHost ["vpn"] "" {})
      (makeClientCertProxy ["hydra"] "http://localhost:${s ports.hydra}" {})

      # (makePassProxy ["sync" "drive"] "" {})
      # (makePassProxy ["music" "mpd"] "" {})
    ]) // {
      ${config.services.jitsi-meet.hostName} = {
        enableACME = true;
        forceSSL = true;
      };
    };

    upstreams = {};

    streamConfig = ''
      upstream minecraft {
        server ${ips.crafty}:${s ports.minecraft};
      }

      server {
        listen 0.0.0.0:${s ports.minecraft};
        listen [::0]:${s ports.minecraft};
        proxy_pass minecraft;
      }
    '';
      # upstream openvpn {
      #   server localhost:${s ports.openvpn};
      # }

      # server {
      #   listen 0.0.0.0:${s ports.openvpn};
      #   listen [::0]:${s ports.openvpn};
      #   proxy_pass openvpn;
      # }
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  #   secrets.ports.openvpn
    ports.minecraft
  ];
}
