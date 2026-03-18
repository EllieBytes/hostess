{ inputs
, lib
, config
, ... }:

let
  inherit (lib) mapAttrsToList filterAttrs types;

  cfg = config.hostess;

  hostNames = builtins.attrNames (
    filterAttrs 
      (_: type: type == "directory")
      (builtins.readDir cfg.hostsDir)
  );

  loadMeta = name: import "${cfg.hostsDir}/${name}/meta.nix" cfg.extraMetaArgs;

  resolveProfiles = tags:
    lib.pipe cfg.perTag [
      (filterAttrs (tag: _: builtins.elem tag tags))
      (mapAttrsToList (_: rule: rule.profiles))
      lib.flatten
    ];

  resolveSpecialArgs = tags:
    lib.pipe cfg.perTag [
      (filterAttrs (tag: _: builtins.elem tag tags))
      (mapAttrsToList (_: rule: rule.extraSpecialArgs))
      (lib.attrsets.mergeAttrsList)
    ];

  mkHost = name:
    let
      meta = loadMeta name;

      users = meta.users or [];

      override = 
      (if meta ? override then 
        (if builtins.isBool meta.override then
          meta.override
        else throw "the `override` option must be of type `bool`")
      else false);

      profiles = 
      (if meta ? profiles then
        (if builtins.isList meta.profiles then
          meta.profiles
        else throw "the `profiles` option must be of type `list`")
      else []);

      tags =
      (if meta ? tags then
        (if builtins.isList meta.profiles then
          meta.tags
        else throw "the `tags` option must be of type `list`")
      else []);

      hasTarget = meta ? targetHost;
    in
    { ... }: {
      nixpkgs = meta.system or "x86_64-linux";

      deployment = lib.mkMerge [
        (lib.mkIf (!hasTarget) {
          inherit tags;
          targetHost = meta.targetHost or null;
          targetUser = meta.targetUser or "root";
          allowLocalDeployment = !(meta ? targetHost);
        })

        (lib.mkIf (meta.buildOnTarget or false) {
          buildOnTarget = true;
        })
      ];

      imports = [
        "${cfg.hostsDir}/${name}"

        {
          home-manager.users = lib.genAttrs users (user: 
            import "${meta.usersDir or throw "Trying to import user from... nowhere please set `hostess.usersDir`"}/${name}"
          );
        }
      ]
      ++ (if override then [] else cfg.defaultModules)
      ++ resolveProfiles tags
      ++ profiles;
    };

in {
  options.hostess = {
    hostsDir = lib.mkOption {
      type = types.path;
      description = "Path to the directory containing host files";
      example = "./hosts";
    };

    usersDir = lib.mkOption {
      type = types.path;
      description = "Path to the directory containing user configs";
      example = "./users";
    };

    defaultModules = lib.mkOption {
      type = types.listOf types.deferredModule;
      description = "Modules to apply to every host (excluding hosts with the override metadata set).";
      example = [ ./modules/default.nix ({}: { boot.loader.systemd-boot.enable = true; }) ];
      default = [];
    };

    defaultExtraSpecialArgs = lib.mkOption {
      type = types.attrsOf types.any;
      description = "Extra args to send to every host config (excluding overrides).";
      default = {};
    };

    extraMetaArgs = lib.mkOption {
      description = "Extra arguments to pass to host meta.nix files";
      type = types.attrsOf types.any;
      default = {};
    };

    perTag = lib.mkOption {
      description = "Rules to apply per tag";
      type = types.attrsOf types.submodule {
        profiles = lib.mkOption {
          type = types.listOf types.deferredModule;
          description = "Profiles to apply to this tag";
          default = [];
        };

        extraSpecialArgs = lib.mkOption {
          type = types.attrsOf types.any;
          description = "Extra arguments to apply to hosts under this tag";
          default = {};
        };
      };
    };
  };

  config = {
    flake.colmena = {
      meta.nixpkgs = (if inputs ? nixpkgs then inputs.nixpkgs else throw "A `nipkgs` input is required.");
    } // lib.genAttrs hostNames mkHost;

    flake.nixosConfigurations = lib.genAttrs hostNames (name:
      let
        meta = loadMeta name;
  
        override = (if meta ? override then
          meta.override
        else
          false);

        tags = (if meta ? tags then tags else []);
      in 
      inputs.nixpkgs.lib.nixosSystem {
        system = meta.system or "x86_64-linux";
        modules = [
          "${cfg.hostsDir}/${name}"
        ] 
        ++ (if override then [] else cfg.defaultModules)
        ++ resolveProfiles tags;

        specialArgs = resolveSpecialArgs tags;
      });
  };
}
