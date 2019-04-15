{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.fefa;
in
{
  config = mkIf (cfg.enable && (cfg.localDnsResolver || (cfg.dnsForwarder != ""))) {
    services.kresd = mkIf cfg.localDnsResolver {
      enable = true;
      extraConfig = mkIf (cfg.dnsForwarder != "") ''
        modules = { 'policy' }
        policy.add(policy.all(policy.STUB('${cfg.dnsForwarder}')))
        modules = { 'hints > iterate' }
        hints.add_hosts()
      '';
    };
    networking.nameservers = if cfg.localDnsResolver
      then ["127.0.0.1"]
      else [cfg.dnsForwarder];
  };
}
