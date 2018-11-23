# Replacement from https://github.com/NixOS/nixpkgs/pull/49620
{pkgs, ...}:
let
  nixpkgs = builtins.fetchTarball {
    url = https://github.com/griff/nixpkgs/archive/0810d631a489fcd819eafc530c45e768570ace8d.tar.gz;
    sha256 = "1nx02w540gal9c0s91jj5704j2pmhq82kp4padkjvp8jwfqpmcsh";
  };
in {
  disabledModules = [
    "services/mail/rspamd.nix"
    "services/mail/rspamd.nix:anon-1"
    "services/mail/rspamd.nix:anon-2"
    "services/mail/rspamd.nix:anon-3"
  ];
  imports = [
    "${nixpkgs}/nixos/modules/services/mail/rspamd.nix"
  ];
}
