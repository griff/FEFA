{ config, pkgs, lib, ... }:

let
  cfg = config.fefa;
in
{
  config = lib.mkIf (cfg.enable && cfg.enableVirusScanning) {
    services.clamav.daemon.enable = true;
    systemd.services.clamav-daemon.serviceConfig.Restart = "on-failure";
    services.clamav.updater.enable = true;
  };
}
