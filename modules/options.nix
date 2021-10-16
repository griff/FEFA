{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.fefa;
  domainModule = {name, config, ...}: {
    options = {
      domain = mkOption {
        type = types.str;
        default = name;
        description = ''
          Domain name
        '';
      };
      backend = mkOption {
        type = types.str;
        example = "192.168.1.1";
        description = ''
          SMTP server to forward incomming mails for this domain to
        '';
      };
      address_verify = mkOption {
        type = types.nullOr types.str;
        example = "[192.168.1.1]";
        default = "[${config.backend}]";
        description = ''
          SMTP server to use for address verification
        '';
      };
      dkim = {
        enable = mkOption {
          type = types.bool;
          default = cfg.rspamd.enable;
          description = ''
            Whether to enable DKIM for this domain
          '';
        };
        selector = mkOption {
          type = types.str;
          default = "mail";
          description = ''
            DKIM selector to use for this domain
          '';
        };
      };
    };
  };
in {
  options.fefa = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to run the Full Email Filtering Actions.
      '';
    };

    tlsProvider = mkOption {
      type = types.enum ["acme" "provided"];
      default = "acme";
      example = "provided";
      description = ''
        How TLS certificates are provisioned
      '';
    };
    tlsChainFiles = mkOption {
      type = types.listOf types.path;
      example = [ /etc/fefa/tls-chain.pem ];
      description = ''
        Paths to files containing TLS certificate chains.
      '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable verbose logging for mailserver related services. This
        intended be used for development purposes only, you probably don't want
        to enable this unless you're hacking on FEFA.
      '';
    };
    domains = mkOption {
      type = types.loaOf (types.submodule domainModule);
      example = [ "example.com" ];
      description = ''
        The domains for which FEFA is responsible.
      '';
    };
    fqdn = mkOption {
      type = types.str;
      example = "mail.example.com";
      description = ''
        The domain the MX record points to and hostname needs not be listed in
        domains. Used by Postfix and ACME.
      '';
    };
    relays = mkOption {
      type = types.listOf types.str;
      description = ''
        Other IPs we allow relay from
      '';
      example = ["192.168.11.0/24"];
      default = [];
    };
    monitorMailAddress = mkOption {
      type = types.str;
      description = ''
        Who should receive certificate alerts.
      '';
      example = "postmaster@example.com";
    };
    localMailRecipient = mkOption {
      type = types.str;
      description = ''
        Who should receive locally generated mails.
      '';
      example = "postmaster@example.com";
    };
    dnsForwarder = mkOption {
      type = types.str;
      default = "";
      description = ''
        DNS Server to forward all DNS requests to.
      '';
    };
    localDnsResolver = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Runs a local DNS resolver (kresd) as recommended when running rspamd. This prevents your log file from filling up with rspamd_monitored_dns_mon entries.
      '';
    };
    enforceTLS = mkOption {
      type = types.bool;
      default = false;
      description = ''
        This forces TLS for all outgoing mails
      '';
    };
    unencryptedSubjects = mkOption {
      type = types.listOf types.str;
      description = ''
        Subject blocks that is used to send messages without TLS.
        This mostly exists to get around <code>enforceTLS</code> option.
      '';
      example = ["ukrypteret" "unencrypted"];
      default = ["ukrypteret" "unencrypted"];
    };
    rspamd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Fast, free and open-source spam (unsolicited bulk email) filtering
          system.
        '';
      };
      enableRedis = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Use Redis backend for Rspamd
        '';
      };
      enableWebUI = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the Rspamd Web UI
        '';
      };
      webUIPassword = mkOption {
        type = types.str;
        description = ''
          Password for accessing controller WebUI.
          This can be encrypted with <literal>rspamadm pw</literal>.
        '';
      };
      historyRows = mkOption {
        type = types.int;
        default = 200;
        description = ''
          Number of rows to keep in WebUI history.
          This is only used when redis is enabled.
        '';
      };
    };
    enableAddressVerification = mkOption {
      type = types.bool;
      default = any (d: d.address_verify != null) (attrValues cfg.domains);
      description = ''
        Enable postfix address verification.
      '';
    };
    enableChunking = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable support for Chunking/BDAT.
        <link xlink:href="http://www.postfix.org/BDAT_README.html"/>
      '';
    };
    enableVirusScanning = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Scan mails for viruses using ClamAV
      '';
    };
    enableDKIM = mkOption {
      type = types.bool;
      default = true;
      description = ''
        A community effort to develop and maintain a C library for producing
        DKIM-aware applications and an open source milter for providing DKIM
        service (<link xlink:href="http://opendkim.org/"/>).
      '';
    };
    enableSPFPolicy = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enforce the Sender Policy Framework.
      '';
    };
    headerChecks = mkOption {
      type = types.listOf (types.submodule {
        options = {
          pattern = mkOption {
            type = types.str;
            default = "/^.*/";
            example = "/^X-Mailer:/";
            description = "A regexp pattern matching the header";
          };
          action = mkOption {
            type = types.str;
            default = "DUNNO";
            example = "BCC mail@example.com";
            description = ''
              The action to be executed when the pattern is matched
            '';
          };
          direction = mkOption {
            type = types.enum ["incoming" "outgoing" "both"];
            default = "both";
            example = "incoming";
            description = ''
              Whether to filter on incoming smtp port (submission) or on
              outgoing smtp port (25) or both.
            '';
          };
        };
      });
      default = [];
      description = "Header Checks on incoming and outgoing smtp port";
      example = lib.literalExample ''
        [ { pattern = "/^X-Spam(.*)/"; action = "IGNORE"; direction = "incoming"; } ]
      '';
    };
  };
  config.fefa.fqdn = mkIf cfg.enable (mkDefault
    (if hasInfix "." config.networking.hostName
    then "${config.networking.hostName}"
    else "${config.networking.hostName}.${config.networking.domain}"));
  config.fefa.localMailRecipient = mkIf cfg.enable (mkDefault cfg.monitorMailAddress);
  config.fefa.tlsChainFiles = mkIf (cfg.enable && cfg.tlsProvider == "acme")
    (mkDefault [
      "/var/lib/acme/${cfg.fqdn}/full.pem"
      "/var/lib/acme/${cfg.fqdn}-ec384/full.pem"
    ]);
}
