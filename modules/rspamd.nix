{config, lib, pkgs, ...}:
with lib;
let
  cfg = config.fefa;
  postfixCfg = config.services.postfix;
  rspamdCfg = config.services.rspamd;
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
        "milter_headers.conf".text = ''
          extended_spam_headers = true;
        '';
        "options.conf".text = ''
          local_addrs = "${concatStringsSep ", " local_ips}";
        '';
        "history_redis.conf" = mkIf cfg.rspamd.enableRedis { text = ''
            nrows = ${toString cfg.rspamd.historyRows};
          '';
        };
        "logging.inc".text = ''
          facility = "mail";
        '';
      };
      overrides = {
        "greylist.conf".text = ''
          whitelisted_ip {
            urls = [
              "$LOCAL_CONFDIR/local.d/greylist-whitelist-ips.inc",
              "sign+key=f7m4jxua6iwtw5966bhfhxqw6xid758nn6putwb51gum9gmzbeqy+https://whitelist.maven-group.org/lists/combined_ip"
            ];
            poll_time = 7d;
          }

          whitelist_domains_url = {
            urls = [
              "$LOCAL_CONFDIR/local.d/greylist-whitelist-domains.inc",
              "sign+key=f7m4jxua6iwtw5966bhfhxqw6xid758nn6putwb51gum9gmzbeqy+https://whitelist.maven-group.org/lists/combined_rspamd_domains"
            ];
            poll_time = 7d;
          }
        '';
      };

      workers.rspamd_proxy = {
        type = "rspamd_proxy";
        bindSockets = [{
          socket = "/run/rspamd/rspamd-milter.sock";
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
    };
    systemd.services.postfix = {
      after = [ "rspamd.service" ];
      requires = [ "rspamd.service" ];
    };
    services.postfix.config = {
      smtpd_milters = [ "unix:/run/rspamd/rspamd-milter.sock" ];
      non_smtpd_milters = [ "unix:/run/rspamd/rspamd-milter.sock" ];
    };
    users.users.${postfixCfg.user}.extraGroups = [ rspamdCfg.group ];
  };
}
