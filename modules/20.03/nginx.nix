{config, lib, ...}:
with lib;
let
  cfg = config.fefa;
in {
  config = mkIf (cfg.enable && ((cfg.rspamd.enable && cfg.rspamd.enableWebUI) || cfg.tlsProvider == "acme")) {
    security.acme.certs."${cfg.fqdn}-ec384" = mkIf (cfg.tlsProvider == "acme") {
      user = "nginx";
    };
  };
}