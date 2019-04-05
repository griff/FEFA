{config, lib, pkgs, ...}:
with lib;
let
  cfg = config.fefa;
  excludeDirection = dir: lib.filter (x: x.direction != dir) cfg.headerChecks;
  checksIncoming = lib.concatMapStringsSep "\n" (x: "${x.pattern} ${x.action}") (excludeDirection "outgoing");
  checksOutgoing = lib.concatMapStringsSep "\n" (x: "${x.pattern} ${x.action}") (excludeDirection "incoming");
in {
  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 25 ];
    services.postfix = {
      enable = true;
      enableHeaderChecks = true;
      masterConfig = {
        smtp_inet = {
          args = [
           "-o" "smtp_header_checks=header_checks_incoming"
          ];
        };
      } // lib.optionalAttrs cfg.enableSPFPolicy {
        policydspf = {
          command = "spawn";
          args = [ "user=nobody" "argv=${pkgs.python36Packages.pypolicyd-spf}/bin/policyd-spf" ];
          privileged = true;
          maxproc = 0;
        };
      };
      setSendmail = true;
      hostname = cfg.fqdn;
      destination = [
        "$myhostname"
        "localhost"
      ];
      networks = ["127.0.0.0/8"]
        ++ (mapAttrsToList (n: d: "${d.backend}") cfg.domains)
        ++ cfg.relays;

      mapFiles."header_checks_outgoing" = pkgs.writeText "header_checks_outgoing" checksOutgoing;
      mapFiles."header_checks_incoming" = pkgs.writeText "header_checks_incoming" checksIncoming;
      mapFiles."tls_policy" = pkgs.writeText "tls_policy"
        (concatStringsSep "\n"
          (mapAttrsToList (n: d: "[${d.backend}] may") cfg.domains));

      transport = concatStringsSep "\n" (mapAttrsToList (n: d: "${d.domain} smtp:[${d.backend}]") cfg.domains);

      postmasterAlias = cfg.localMailRecipient;
      rootAlias = cfg.localMailRecipient;

      config = {
        # TLS settings, inspired by https://github.com/jeaye/nix-files
        # Submission by mail clients is handled in submissionOptions
        smtpd_tls_security_level = "may";
        # strong might suffice and is computationally less expensive
        smtpd_tls_eecdh_grade = "ultra";
        # Allowing AUTH on a non encrypted connection poses a security risk
        smtpd_tls_auth_only = "yes";
        # Log only a summary message on TLS handshake completion
        smtpd_tls_loglevel = "1";

        smtp_tls_security_level = mkIf cfg.enforceTLS "verify";
        smtp_tls_policy_maps = "hash:/etc/postfix/tls_policy";


        # Disable weak ciphers as reported by https://ssl-tools.net
        # https://serverfault.com/questions/744168/how-to-disable-rc4-on-postfix
        smtpd_tls_exclude_ciphers = "RC4, aNULL";
        smtp_tls_exclude_ciphers = "RC4, aNULL";
        smtpd_tls_received_header = true;

        message_size_limit = "100480000";
        mailbox_size_limit = "100480000";

        delay_warning_time = "1h";
        maximal_queue_lifetime = "1d";

        local_recipient_maps = "$alias_maps";

        relay_domains = "hash:/etc/postfix/transport";

        # Workaround for stupid Cisco ASA
        smtp_always_send_ehlo = true;
        smtp_pix_workarounds = "";

        #smtp_bind_address = cfg.ipAddress;
        #smtp_bind_address6 = cfg.ip6Address;

        smtpd_relay_restrictions = [
          "reject_non_fqdn_recipient"
          "reject_unknown_recipient_domain"
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "reject_unauth_destination"
        ];
        smtpd_client_restrictions = [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          #"reject_unknown_reverse_client_hostname" # reject when no reverse PTR
        ];
        smtpd_helo_required = "yes";
        smtpd_helo_restrictions = [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "reject_invalid_helo_hostname"
          "reject_non_fqdn_helo_hostname"
          "reject_unknown_helo_hostname"
        ];

        # Add some security
        smtpd_recipient_restrictions = [
          "reject_unknown_sender_domain"    # prevents spam
          "reject_unknown_recipient_domain" # prevents spam
          "reject_unauth_pipelining"        # prevent bulk mail spam
          "permit_sasl_authenticated"
          "permit_mynetworks"
          "reject_unauth_destination"
        ] ++ lib.optional cfg.enableSPFPolicy "check_policy_service unix:private/policydspf"; # policyd-spf
      } /*// lib.optionalAttrs cfg.enableDKIM {
        smtpd_milters = [ "unix:/run/opendkim/opendkim.sock" ];
        non_smtpd_milters = [ "unix:/run/opendkim/opendkim.sock" ];
      }*/;
      sslCert = "/var/lib/acme/${cfg.fqdn}/fullchain.pem";
      sslKey  = "/var/lib/acme/${cfg.fqdn}/key.pem";
      sslCACert = "/etc/ssl/certs/ca-certificates.crt";
    };
    systemd.services.postfix.restartTriggers = [config.environment.etc."ssl/certs/ca-certificates.crt".source];
  };
}
