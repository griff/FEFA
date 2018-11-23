{config, lib, ...}:
with lib;
let
  cfg = config.fefa;
in {

  config = mkIf (cfg.enable && cfg.enableDKIM) {
    /*
    users.users.postfix.extraGroups = [ "opendkim" ];
    services.opendkim = {
      enable = true;
      selector = "mail";
      keyPath = "/var/lib/dkim/keys/";
      domains = "csl:${lib.concatStringsSep "," cfg.domains}";
      configFile = pkgs.writeText "opendkim.conf" ''
        UMask 0002
      '';
    };
    */
  };
}
