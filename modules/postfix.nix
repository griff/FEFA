{config, lib, pkgs, ...}:
with lib;
let
  cfg = config.fefa;
  excludeDirection = dir: lib.filter (x: x.direction != dir) cfg.headerChecks;
  checksIncoming = lib.concatMapStringsSep "\n" (x: "${x.pattern} ${x.action}") (excludeDirection "outgoing");
  checksOutgoing = lib.concatMapStringsSep "\n" (x: "${x.pattern} ${x.action}") (excludeDirection "incoming");
  msaHeaderChecks = pkgs.writeText "msa_header_checks"
        (optionalString cfg.enforceTLS (concatStringsSep "\n" (map (subject:
            "/^X-AllowNoTLS: [ ]*yes$/ FILTER smtp_notls:"
          ) cfg.unencryptedSubjects)));
  msaBodyChecks = pkgs.writeText "msa_body_checks" "";
in {
  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 25 587 ];
    services.subjectmilter = {
      enable = cfg.enforceTLS;
      unencryptedSubjects = cfg.unencryptedSubjects;
    };
    services.postfix = {
      enable = true;
      enableHeaderChecks = true;
      masterConfig = {
        smtp_inet = {
          args = [
           "-o" "smtp_header_checks=header_checks_incoming"
          ];
        };
        msa_cleanup = {
          command = "cleanup";
          private = false;
          maxproc = 0;
          args = [
            "-o" "header_checks=$msa_header_checks"
            "-o" "milter_header_checks=$msa_milter_header_checks"
            "-o" "body_checks=$msa_body_checks"
          ];
        };
      } // optionalAttrs cfg.enforceTLS {
        smtp_notls = {
          command = "smtp";
          args = [
            "-o" "smtp_tls_security_level=may"
          ];
        };
      } // optionalAttrs cfg.enableSPFPolicy {
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

      mapFiles."address_verify_transport" = pkgs.writeText "address_verify_transport"
        (concatStringsSep "\n"
          (mapAttrsToList (n: d: "${d.domain} smtp:${d.address_verify}") cfg.domains));
      mapFiles."header_checks_outgoing" = pkgs.writeText "header_checks_outgoing" checksOutgoing;
      mapFiles."header_checks_incoming" = pkgs.writeText "header_checks_incoming" checksIncoming;
      mapFiles."tls_policy" = pkgs.writeText "tls_policy"
        (concatStringsSep "\n"
          (mapAttrsToList (n: d: "[${d.backend}] may") cfg.domains));

      transport = concatStringsSep "\n" (mapAttrsToList (n: d: "${d.domain} smtp:[${d.backend}]") cfg.domains);

      postmasterAlias = cfg.localMailRecipient;
      rootAlias = cfg.localMailRecipient;

      config = {
        #
        #debug_peer_list = "192.168.10.1";
        # Disable Chunking/BDAT
        smtpd_discard_ehlo_keywords = mkIf (!cfg.enableChunking) "chunking";

        address_verify_transport_maps = [ "hash:/etc/postfix/address_verify_transport" ];

        msa_cleanup_service_name = "msa_cleanup";
        msa_header_checks = "pcre:${msaHeaderChecks}";
        msa_milter_header_checks = "pcre:${msaHeaderChecks}";
        msa_body_checks = "pcre:${msaBodyChecks}";

        # TLS settings, inspired by https://github.com/jeaye/nix-files
        # Submission by mail clients is handled in submissionOptions
        smtpd_tls_security_level = "may";
        # strong might suffice and is computationally less expensive
        smtpd_tls_eecdh_grade = "ultra";
        smtpd_tls_dh1024_param_file = "${../ffdhe3072.pem}";
        # Allowing AUTH on a non encrypted connection poses a security risk
        smtpd_tls_auth_only = "yes";
        # Log only a summary message on TLS handshake completion
        smtpd_tls_loglevel = "1";
        smtp_tls_loglevel = "1";

        smtp_tls_CAfile = "/etc/ssl/certs/ca-certificates.crt";
        #smtpd_tls_CAfile = "/etc/ssl/certs/ca-certificates.crt";
        smtpd_tls_chain_files = [
          "/var/lib/acme/${cfg.fqdn}/full.pem"
          "/var/lib/acme/${cfg.fqdn}-ec384/full.pem"
        ];

        smtp_tls_security_level = if cfg.enforceTLS then "encrypt" else "may";
        smtp_tls_policy_maps = "hash:/etc/postfix/tls_policy";
        smtpd_tls_mandatory_protocols = "!SSLv2, !SSLv3";
        smtpd_tls_protocols = "!SSLv2, !SSLv3";
        smtp_tls_mandatory_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";
        smtp_tls_protocols = "!SSLv2, !SSLv3";

        # Disable weak ciphers as reported by https://ssl-tools.net
        # https://serverfault.com/questions/744168/how-to-disable-rc4-on-postfix
        smtpd_tls_exclude_ciphers = "RC4, aNULL";
        smtp_tls_exclude_ciphers = "RC4, aNULL";
        tls_ssl_options="NO_RENEGOTIATION";
        tls_preempt_cipherlist = true;
        tls_medium_cipherlist = "ECDSA+AESGCM:ECDH+AESGCM:DH+AESGCM:ECDSA+AES:ECDH+AES:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS";
        smtpd_tls_received_header = true;

        message_size_limit = "100480000";
        mailbox_size_limit = "100480000";

        delay_warning_time = "1h";
        maximal_queue_lifetime = "1d";
        bounce_queue_lifetime = "1d";

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
        ] ++ (lib.optional (!cfg.enforceTLS) "permit_mynetworks") ++ [
          "permit_sasl_authenticated"
          "reject_unauth_destination"
        ];
        # (lib.optional !cfg.enforceTLS "permit_mynetworks") ++
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
          #"reject_unknown_helo_hostname"
        ];

        # Add some security
        smtpd_recipient_restrictions = [
          "reject_unknown_sender_domain"    # prevents spam
          "reject_unknown_recipient_domain" # prevents spam
          "reject_unauth_pipelining"        # prevent bulk mail spam
          "permit_sasl_authenticated"
          "permit_mynetworks"
          "reject_unverified_recipient"
          "reject_unauth_destination"
        ] ++ lib.optional cfg.enableSPFPolicy "check_policy_service unix:private/policydspf"; # policyd-spf
        unverified_recipient_reject_reason = "Address lookup failed";
        # unverified_recipient_reject_code = "550";
      } /*// lib.optionalAttrs cfg.enableDKIM {
        smtpd_milters = [ "unix:/run/opendkim/opendkim.sock" ];
        non_smtpd_milters = [ "unix:/run/opendkim/opendkim.sock" ];
      }*/;
      #sslCert = "/var/lib/acme/${cfg.fqdn}/fullchain.pem";
      #sslKey  = "/var/lib/acme/${cfg.fqdn}/key.pem";
      #sslCACert = "/etc/ssl/certs/ca-certificates.crt";
      enableSubmission = true;
      submissionOptions = {
        smtpd_tls_security_level = "may";
        smtpd_tls_auth_only = "yes";
        smtpd_sasl_auth_enable = "no";
        #smtpd_sasl_auth_enable = "yes";
        #smtpd_sasl_security_options = "noanonymous,noplaintext";
        #smtpd_sasl_tls_security_options = "noanonymous";
        smtpd_client_restrictions = "permit_mynetworks,permit_sasl_authenticated,reject";
        smtpd_relay_restrictions = "reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_mynetworks,permit_sasl_authenticated,permit_sasl_authenticated,reject_unauth_destination";
        #milter_macro_daemon_name = "ORIGINATING";
        cleanup_service_name = "$msa_cleanup_service_name";
      };
    };
    systemd.services.postfix.restartTriggers = [config.environment.etc."ssl/certs/ca-certificates.crt".source];
  };
}
