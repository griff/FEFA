{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.fefa;
  ucfg = config.services.unbound;
  stateDir = "/var/lib/unbound";
  unboundWrapped = pkgs.stdenv.mkDerivation {
      name = "unbound-wrapped";

      buildInputs = [ pkgs.makeWrapper ucfg.package ];

      phases = [ "installPhase" ];

      installPhase = ''
        mkdir -p "$out/bin"
        makeWrapper ${ucfg.package}/bin/unbound-control $out/bin/unbound-control \
          --add-flags "-c ${stateDir}/unbound.conf"
        makeWrapper ${ucfg.package}/bin/unbound-checkconf $out/bin/unbound-checkconf \
          --add-flags "${stateDir}/unbound.conf"
      '';
    };
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
    environment.systemPackages = mkIf cfg.localDnsResolver [ (hiPrio unboundWrapped) ];
    services.unbound = mkIf cfg.localDnsResolver {
      enable = true;
      forwardAddresses = mkIf (cfg.dnsForwarder != "") [cfg.dnsForwarder];
      #extraConfig = ''
      #  server:
      #    val-permissive-mode: yes
      #'';
      extraConfig = ''
        remote-control:
          control-enable: "yes"
          server-key-file: ${stateDir}/unbound_server.key
          server-cert-file: ${stateDir}/unbound_server.pem
          control-key-file: ${stateDir}/unbound_control.key
          control-cert-file: ${stateDir}/unbound_control.pem
          control-port: 8953
          control-interface: 127.0.0.1
      '';
    };
    networking.nameservers = if cfg.localDnsResolver
      then ["127.0.0.1"]
      else [cfg.dnsForwarder];
    systemd.services.unbound = mkIf cfg.localDnsResolver {
      path = [ pkgs.openssl ];
      preStart = ''
        ${ucfg.package}/bin/unbound-control-setup -d ${stateDir}
      '';
    };
  };
}
