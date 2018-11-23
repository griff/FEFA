{config, lib, ...}:
with lib;
let
  cfg = config.fefa;
  postfixCfg = config.services.postfix;
  rspamdCfg = config.services.rspamd;
in {
  config = mkIf (cfg.enable && cfg.rspamd.enableRedis) {
    services.redis = {
      enable = true;
      bind = "127.0.0.1";
    };
  };
}
