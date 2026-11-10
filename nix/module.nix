self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.simple-moderation;
in
{
  options.services.simple-moderation = {
    enable = lib.mkEnableOption "DeepSeek moderation HTTP service";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Moderation application package.";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "HTTP listen address.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 18765;
      description = "HTTP listen port.";
    };
    apiKeyFile = lib.mkOption {
      type = lib.types.str;
      description = "Runtime path to the DeepSeek API key; never a Nix store path.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.apiKeyFile && !(lib.hasPrefix "/nix/store/" cfg.apiKeyFile);
        message = "simple-moderation.apiKeyFile must be an absolute runtime secret path.";
      }
    ];
    systemd.services.simple-moderation = {
      description = "DeepSeek moderation HTTP service";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "exec";
        DynamicUser = true;
        ExecStart = lib.escapeShellArgs [
          "${cfg.package}/bin/simple-moderation"
          "serve"
          "--host"
          cfg.host
          "--port"
          (toString cfg.port)
          "--api-key-file"
          "%d/deepseek-api-key"
        ];
        LoadCredential = [ "deepseek-api-key:${cfg.apiKeyFile}" ];
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 10;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        CapabilityBoundingSet = "";
      };
    };
  };
}
