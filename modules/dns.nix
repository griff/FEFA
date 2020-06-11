{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.fefa;
in
{
  config = mkIf (cfg.enable && (cfg.localDnsResolver || (cfg.dnsForwarder != ""))) {
    /*
    services.kresd = mkIf cfg.localDnsResolver {
      enable = true;
      extraConfig = if (cfg.dnsForwarder != "") then ''
        modules = { 'policy' }
        policy.add(policy.all(policy.STUB('${cfg.dnsForwarder}')))
        modules = { 'hints > iterate' }
        hints.add_hosts()
      '' else ''
        modules = { 'hints > iterate' }
        hints.add_hosts()
      '';
    };
    */
    services.unbound = mkIf cfg.localDnsResolver {
      enable = true;
      forwardAddresses = mkIf (cfg.dnsForwarder != "") [cfg.dnsForwarder];
      #extraConfig = ''
      #  server:
      #    val-permissive-mode: yes
      #'';
    };
    networking.nameservers = if cfg.localDnsResolver
      then ["127.0.0.1"]
      else [cfg.dnsForwarder];
  };
}
