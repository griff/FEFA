{config, lib, ...}:
with lib;
let
  cfg = config.fefa;
in {
  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      upstreams.rspamd = mkIf cfg.rspamd.enable {
        servers."unix:/run/rspamd/worker-controller.sock" = {};
      };
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.fqdn}" = {
        serverName = cfg.fqdn;
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = mkIf cfg.rspamd.enable "http://rspamd";
      };
    };

    security.acme.certs."${cfg.fqdn}" = {
      email = cfg.monitorMailAddress;
      postRun = ''
        systemctl reload postfix
      '';
    };
  };
}
