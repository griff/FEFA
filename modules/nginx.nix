{config, lib, ...}:
with lib;
let
  cfg = config.fefa;
  ncfg = config.services.nginx;
in {
  config = mkIf (cfg.enable && ((cfg.rspamd.enable && cfg.rspamd.enableWebUI) || cfg.tlsProvider == "acme")) {
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    services.nginx = {
      enable = true;
      upstreams.rspamd = mkIf (cfg.rspamd.enable && cfg.rspamd.enableWebUI) {
        servers."unix:/run/rspamd/worker-controller.sock" = {};
      };
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.fqdn}" = {
        serverName = cfg.fqdn;
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = mkIf (cfg.rspamd.enable && cfg.rspamd.enableWebUI) "http://rspamd";
      };
    };

    security.acme.certs."${cfg.fqdn}" = {
      email = cfg.monitorMailAddress;
      postRun = ''
        systemctl reload postfix
      '';
      keyType = "rsa4096";
      #extraLegoRunFlags = [ "--preferred-chain" "ISRG Root X1" ];
    };
    security.acme.certs."${cfg.fqdn}-ec384" = mkIf (cfg.tlsProvider == "acme") {
      group = ncfg.group;
      domain = cfg.fqdn;
      keyType = "ec384";
      email = cfg.monitorMailAddress;
      webroot = "/var/lib/acme/acme-challenge";
      postRun = ''
        systemctl reload postfix
      '';
      #extraLegoRunFlags = [ "--preferred-chain" "ISRG Root X1" ];
    };
  };
}
