{config, lib, ...}:
with lib;
let
  cfg = config.fefa;
in {
  config = mkIf (cfg.enable && cfg.rspamd.enableRedis) {
    services.redis.servers.default = {
      enable = true;
      bind = "127.0.0.1";
    };
  };
}
