{config, lib, pkgs, ...}:
with lib;
let
  cfg = config.fefa;
  dkimDomains = filterAttrs (n: d: d.dkim.enable) cfg.domains;
  dkimConfig = mapAttrsToList (name: d: ''
    domain {
      ${d.domain} {
        path = "/var/lib/rspamd/dkim/${d.domain}.${d.dkim.selector}.key"
        selector = "${d.dkim.selector}"
      }
    }
  '') dkimDomains;
  dkimCreateKeys = mapAttrsToList (name: d: let
      keyPrefix = "/var/lib/rspamd/dkim/${d.domain}.${d.dkim.selector}";
    in ''
    if [ ! -f "${keyPrefix}.key" ]; then
      echo "Creating DKIM key for ${d.domain}"
      ${pkgs.rspamd}/bin/rspamadm dkim_keygen \
        -s ${d.dkim.selector} -d ${d.domain} \
        -k ${keyPrefix}.key > ${keyPrefix}.dns
    else
      echo "DKIM key for ${d.domain} already exists"
    fi

  '') dkimDomains;
  local_ips = ["127.0.0.0/8"]
    ++ (mapAttrsToList (n: d: "${d.backend}") cfg.domains)
    ++ cfg.relays;
in {
  config = mkIf (cfg.enable && cfg.rspamd.enable) {
    services.rspamd = {
      enable = true;
      debug = cfg.debug;
      extraConfig = ''

      '';
      locals = {
        "antivirus.conf" = mkIf cfg.enableVirusScanning {
          text = ''
            clamav {
              action = "reject";
              symbol = "CLAM_VIRUS";
              type = "clamav";
              log_clean = true;
              servers = "/run/clamav/clamd.ctl";
            }
          '';
        };
        "dkim_signing.conf" = mkIf cfg.enableDKIM { text = ''
            path = "/var/lib/rspamd/dkim/$domain.$selector.key";
            use_esld = false;
          '' + (concatStringsSep "\n" dkimConfig);
        };
        "redis.conf" = mkIf cfg.rspamd.enableRedis { text = ''
            servers = "127.0.0.1";
          '';
        };
        "milter_headers.conf".text = ''
          extended_spam_headers = true;
        '';
        "options.conf".text = ''
          local_addrs = "${concatStringsSep ", " local_ips}";
        '';
        "greylist.conf".text = ''
          whitelisted_ip {
            name = "Whitelisted IPs";
            urls = [
              "sign+key=f7m4jxua6iwtw5966bhfhxqw6xid758nn6putwb51gum9gmzbeqy+https://whitelist.maven-group.org/lists/combined_ip"

            ];
            poll_time = 7d;
          }

          whitelist_domains_url {
            name = "Whitelisted Domains";
            urls = [
              "sign+key=f7m4jxua6iwtw5966bhfhxqw6xid758nn6putwb51gum9gmzbeqy+https://whitelist.maven-group.org/lists/combined_rspamd_domains"
            ];
            poll_time = 7d;
          }
        '';
      };

      workers.rspamd_proxy = {
        type = "proxy";
        bindSockets = [{
          socket = "/run/rspamd/rspamd-milter.sock";
          owner = "rspamd";
          group = "postfix";
          mode = "0660";
        }];
        count = 1; # Do not spawn too many processes of this type
        extraConfig = ''
          milter = yes; # Enable milter mode
          timeout = 120s; # Needed for Milter usually

          upstream "local" {
            default = yes; # Self-scan upstreams are always default
            self_scan = yes; # Enable self-scan
          }
        '';
      };
      workers.controller = {
        type = "controller";
        count = 1;
        bindSockets = [{
          socket = "/run/rspamd/worker-controller.sock";
          mode = "0666";
        }];
        extraConfig = ''
          static_dir = "''${WWWDIR}";
          secure_ip = null;
        '' + (optionalString cfg.rspamd.enableWebUI ''
          password = "${cfg.rspamd.webUIPassword}";
        '');
        includes = [];
      };

    };
    systemd.services.rspamd = {
      preStart = mkIf cfg.enableDKIM (mkAfter (''
        mkdir -p /var/lib/rspamd/dkim
      '' + (concatStringsSep "\n" dkimCreateKeys) + ''
        chown -R rspamd:rspamd /var/lib/rspamd/dkim
      ''));
      after = mkIf cfg.rspamd.enableRedis [ "redis.service" ];
      requires = mkIf cfg.rspamd.enableRedis [ "redis.service" ];
    };
    systemd.services.postfix = {
      after = [ "rspamd.service" ];
      requires = [ "rspamd.service" ];
    };
    services.postfix.config = {
      smtpd_milters = [ "unix:/run/rspamd/rspamd-milter.sock" ];
      non_smtpd_milters = [ "unix:/run/rspamd/rspamd-milter.sock" ];
    };
  };
}
