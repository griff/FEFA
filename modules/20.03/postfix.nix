{config, lib, pkgs, ...}:
with lib;
let
  cfg = config.fefa;
in {
  config = mkIf cfg.enable {
    services.postfix.config = {
      smtp_tls_CAfile = "/etc/ssl/certs/ca-certificates.crt";
    };
  };
}