{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.fefa;
  stateDir = "/var/lib/unbound";
in {
  config = mkIf (cfg.enable && cfg.localDnsResolver) {
      #extraConfig = ''
      #  server:
      #    val-permissive-mode: yes
      #'';

    services.unbound.extraConfig = ''
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
}