{config, lib, ...}:
with lib;
let
  cfg = config.fefa;
in {
  config = mkIf (cfg.enable && cfg.rspamd.enableRedis) {
    services.redis = {
      enable = true;
      bind = "127.0.0.1";
    };
    systemd.services.rspamd = {
      after = [ "redis.service" ];
      requires = [ "redis.service" ];
    };
    services.rspamd.locals."redis.conf".text = ''
      servers = "127.0.0.1";
    '';
  };
}
