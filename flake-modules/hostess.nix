{ inputs
, config
, lib
, flake-parts-lib
, ... }:

let
  inherit (lib)
    mkOption
    types
    filterAttrs
    optionalAttrs
    optional
    optionals
    attrNames
    hasAttr;

  inherit (builtins)
    mapAttrs
    pathExists;

  inherit (flake-parts-lib)
    mkPerSystemOption;

  mkPathOption = (desc: mkOption {
    type = types.nullOr types.path;
    default = null;
    description = desc;
  });
in {
  options.hostess = {
    hostsDir = mkPathOption "Path to the hosts directory containing host configurations.";
    homeDir = mkPathOption "Path to the home directory containing home-manager configurations.";
    modulesDir = mkPathOption "Path to the global modules directory. this will be searched for global modules.";
    homeModulesDir = mkPathOption "Path to the global home modules directory. this will be searched for global home modules.";
    profilesDir = mkPathOption "Path to the global profiles directory. This will be searched for global profiles.";
 
    nixpkgs = mkOption {
      type = types.raw;
      description = "Injected nixpkgs input used to build hosts.";
    };

    home-manager = mkOption {
      type = types.nullOr types.raw;
      default = null;
      description = "Injected home-manager input used to build home-manager configs";
    };

    commonNixosModules = mkOption {
      type = types.listOf types.deferredModule;
      default = [];
      description = "Extra NixOS modules to apply to each host.";
    };

    commonHomeModules = mkOption {
      type = types.listOf types.deferredModule;
      default = [];
      description = "Extra HM Modules to apply to each home configuration";
    };
    
    commonNixpkgsConfig = mkOption {
      type = types.raw;
      description = "A common nixpkgs configuration for each host.";
    };

    commonOverlays = mkOption {
      type = types.listOf types.raw;
      description = "A common set of nixpkgs overlays";
      default = [];
    };

    perTagRules = mkOption {
      description = "Rules to apply to host tags.";
      default = {};
      type = types.attrsOf types.submodule {
        extraSpecialArgs = mkOption {
          description = "Extra arguments to pass to modules for hosts under this tag";
          type = types.raw;
          default = {};
        };

        modules = mkOption {
          description = "Extra modules to pass to every host under this tag";
          type = types.listOf types.str;
          default = [];
        };

        rawModules = mkOption {
          description = "Extra (raw) modules to pass to every host under this tag";
          type = types.listOf types.deferredModule;
          default = [];
        };

        profiles = mkOption {
          description = "Extra profiles to pass to every host under this tag";
          type = types.listOf types.str;
          default = [];
        };

        rawProfiles = mkOption {
          description = "Extra (raw) profiles to pass to every host under this tag";
          type = types.listOf types.deferredModule;
          default = [];
        };
      };
    };
  };

  config =
  let
    cfg = config.hostess;
  in {
    flake = 
    let
      subdirs = dir:
        attrNames (filterAttrs (_: t: t == "directory") (builtins.readDir dir));

      safeImport = path: default:
        if pathExists path then import path else default;

      resolveModule = modulesDir: name:
        let p = modulesDir + "/${name}.nix"; in
        if pathExists p then p
        else throw "hostess: Couldn't find module ${name} at ${p}";

      resolveProfile = profilesDir: name:
        let p = profilesDir + "/${name}.nix"; in
        if pathExists p then p
        else throw "hostess: Couldn't find profile ${name} at ${p}";
       
      buildHost = hostname:
        let
          hostDir = cfg.hostDir + "/${hostname}";
          metaPath = hostDir + "/meta.nix";
          meta = safeImport metaPath {
            system = "x86_64-linux";
            tags = [];
            modules = [];
            profiles = [];
            rawModules = [];
            rawProfiles = [];
            meta = [];
          };

          system = meta.system or "x86_64-linux";
          pkgs   = import cfg.nixpkgs {
            inherit system;
            config = cfg.commonNixpkgsConfig;
            overlays = cfg.commonOverlays;
          };

          commonModule = d: optional
            (pathExists (d + "/common.nix"))
            (d + "/common.nix");

          namedModules = map (resolveModule cfg.modulesDir) (meta.modules or []);
          namedProfiles = map (resolveModule cfg.profilesDir) (meta.profiles or []);

          rawModules = meta.rawModules or [];
          rawProfiles = meta.rawModules or [];

          tagModulesList = builtins.concatLists (map (tag: cfg.perTagRules."${tag}".modules or []) (meta.tags or []));
          tagProfilesList = builtins.concatLists (map (tag: cfg.perTagRules."${tag}".modules or []) (meta.tags or []));

          hmConfig = meta.home-manager or {};
          hmEnabled = (hmConfig.enable or false) && !(isNull cfg.home-manager);
          hmUsers = hmConfig.users or [];

          hmModule = optionals hmEnabled [
            cfg.home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = hmConfig.useGlobalPkgs or true;
              home-manager.useUserPackages = hmConfig.useUserPackages or true;
              home-manager.users = builtins.listToAttrs (map (user: 
                let
                  userDir = cfg.homeDir + "/user";
                  userMeta = safeImport (userDir + "/meta.nix") {
                    modules  = [];
                    profiles = [];
                    rawModules = [];
                    rawProfiles = [];
                    meta     = {};
                  };

                  homeCommon = optional
                    (pathExists (cfg.homeModulesDir + "/common.nix"))
                    (cfg.homeModulesDir + "/common.nix");
                  homeNamed = map (resolveModule cfg.homeModulesDir) (userMeta.modules or []);
                  homeProfiles = map (resolveProfile cfg.homeModulesDir) (userMeta.profiles or []);
                in {
                name = user;
                value = { ... }: {
                  imports = 
                    homeCommon
                    ++ homeNamed
                    ++ (meta.rawModules or [])
                    ++ homeProfiles
                    ++ (meta.rawProfiles or [])
                    ++ cfg.commonHomeModules
                    ++ [ (cfg.userDir + "/default.nix") ];
                };
              }
            ) hmUsers);
          }
        ];

      metadataModule = {
        _module.args.hostMeta = meta.meta or {};
        networking.hostName = lib.mkDefault hostname;
      }; 
    in cfg.nixpkgs.lib.nixosSystem {
      inherit system pkgs;
      modules = 
        commonModule
        ++ namedModules
        ++ rawModules
        ++ namedProfiles
        ++ rawProfiles
        ++ cfg.commonNixosModules
        ++ hmModule
        ++ [
          metadataModule
          (hostDir + "/default.nix")
        ];
      specialArgs = {
        inherit inputs;
        hostMeta = meta.meta or {};
      };
    };

    buildHomeConfig = username:
      let 
        userDir = cfg.homeDir + "/${username}";
        metaPath = userDir + "/meta.nix";
        meta = safeImport metaPath {
          system = "x86_64-linux";
          modules = [];
          rawModules = [];
          profiles = [];
          rawProfiles = [];
          meta = {};
          standalone = false;
        };

        isStandalone = meta.standalone or false;

        system = meta.system or "x86_64-linux";
        pkgs = import cfg.nixpkgs {
          inherit system;
          config   = cfg.commonNixpkgsConfig;
          overlays = cfg.commonOverlays;
        };

        homeCommon = optional
          (pathExists (cfg.homeModulesDir + "/common.nix"))
          (cfg.homeModulesDir + "/common.nix");

        namedModules = map (resolveModule cfg.homeModulesDir) (meta.modules or []);
        namedProfiles = map (resolveProfile cfg.homeProfilesDir) (meta.profiles or []);

        metadataModule = {
          _module.args.userMeta = meta.meta or {};
        };
      in 
        if !isStandalone then null
        else cfg.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules =
            homeCommon
            ++ namedModules
            ++ (meta.rawModules or [])
            ++ namedProfiles
            ++ (meta.rawProfiles or [])
            ++ cfg.commonHomeModules
            ++ [
              metadataModule
              (userDir + "/default.nix")
            ];

          extraSpecialArgs = {
            inherit inputs;
            userMeta = meta.meta or {};
          };
        };

      hostNames = subdirs cfg.hostsDir;
      userNames = if pathExists cfg.homeDir then subdirs cfg.homeDir else [];
      
      nixosConfigurations = builtins.listToAttrs (map (name: {
        inherit name;
        value = buildHost name;
      }) hostNames);

      homeConfigurations = filterAttrs (_: v: v != null)
          (builtins.listToAttrs (map (name: {
            inherit name;
            value = buildHomeConfig name;
          }) userNames));
    in {
      inherit nixosConfigurations homeConfigurations;
      inherit (config) hostess;
    };
  };
}
