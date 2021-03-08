{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.services.subjectmilter;
  subjects = pkgs.writeText "unencrypted-subjects"
    (concatStringsSep "\n" (map (subject:
        "[${subject}]"
      ) cfg.unencryptedSubjects));

in {
  options.services.subjectmilter = {
    enable = mkEnableOption "Subject milter";

    unencryptedSubjects = mkOption {
      type = types.listOf types.str;
      description = ''
        Subject blocks that is used to send messages without TLS.
        This mostly exists to get around <code>enforceTLS</code> option.
      '';
      example = ["ukrypteret" "unencrypted"];
      default = ["ukrypteret" "unencrypted"];
    };
  };
  config = mkIf cfg.enable {
    services.postfix.config = {
        smtpd_milters = mkAfter [ "inet:127.0.0.1:1339" ];
        non_smtpd_milters = mkAfter [ "inet:127.0.0.1:1339" ];
    };
    systemd.services.subjectmilter = {
      description = "Subject milter";

      before = [ "postfix.service" ];
      requiredBy = [ "postfix.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.subjectmilter}/bin/subjectmilter ${subjects}";
      };
    };
  };
}