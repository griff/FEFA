{config, lib, ...}:
with lib;
let
  cfg = config.fefa;
in {
  config = mkIf (cfg.enable && cfg.rspamd.enableRedis) {
    services.redis.servers.fefa = {
      enable = true;
    };
    users.groups."redis-fefa".members = [ "rspamd" ];
    systemd.services.rspamd = {
      after = [ "redis-fefa.service" ];
      requires = [ "redis-fefa.service" ];
    };
    services.rspamd.locals."redis.conf".text = ''
      servers = "/run/redis-fefa/redis.sock";
    '';
  };
}
