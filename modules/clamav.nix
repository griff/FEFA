{ config, pkgs, lib, ... }:

let
  cfg = config.fefa;
in
{
  config = lib.mkIf (cfg.enable && cfg.enableVirusScanning) {
    services.clamav.daemon.enable = true;
    services.clamav.updater.enable = true;
  };
}
