{
  inputs,
  config,
  lib,
  ...
}:

let
  inherit (builtins)
    mapAttrs
    pathExists
    readDir
    tryEval
    filter
    length
    isString
    isFunction
    isAttrs
    ;

  inherit (lib)
    mkOption
    types
    submodule
    optional
    optionals
    attrNames
    hasAttr
    filterAttrs
    literalExpression
    genAttrs'
    ;
in
{
  options.hostess =
    let
      mkInputOption =
        n:
        mkOption {
          type = types.raw;
          example = literalExpression "inputs.${n}";
          description = ''
            Injected input for ${n}.
          '';
        };

      mkOptionalInputOption =
        n:
        mkOption {
          type = types.nullOr types.raw;
          default = null;
          description = ''
            (Optional) Injected input for ${n}.
          '';
        };

      mkPathOption =
        n: d:
        mkOption {
          type = types.nullOr types.path;
          default = d;
          description = ''
            The ${n} path.
          '';
        };

      cfg = config.hostess;
    in
    {
      # Injected inputs.
      nixpkgs = mkInputOption "nixpkgs"; # Doy.
      home-manager = mkInputOption "Home Manager"; # (Optional) handles Home Manager configs automatically.
      disko = mkOptionalInputOption "Disko"; # (Optional) handles disko automatically.

      # Path options.
      root = mkPathOption "root" null;
      hostPath = mkPathOption "host" (cfg.root + "/hosts");
      homePath = mkPathOption "home" null;

      nixosModulePath = mkPathOption "nixos modules" (cfg.root + "/modules/nixos");
      nixosModulePaths = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = ''
          NixOS module search paths.
        '';
      };

      homeModulePath = mkPathOption "Home Manager modules" null;
      homeModulePaths = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = ''
          Home Manager module search paths.
        '';
      };

      profilePath = mkPathOption "profiles" (cfg.root + "/profiles");
      profilePaths = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = ''
          Profile search paths.
        '';
      };

      namespaces = mkOption {
        type = types.attrsOf types.submodule {
          options = {
            nixosModulePaths = mkOption {
              type = types.listOf types.path;
              default = [ ];
              description = ''
                NixOS module search paths in this namespace.
              '';
            };

            homeModulePaths = mkOption {
              type = types.listOf types.path;
              default = [ ];
              description = ''
                Home Manager module search paths in this namespace.
              '';
            };

            profilePaths = mkOption {
              type = types.listOf types.path;
              default = [ ];
              description = ''
                Profile search paths in this namespace.
              '';
            };
          };
        };
      };

      # Configs.
      commonNixosModules = mkOption {
        type = types.listOf types.raw;
        default = [ ];
        example = [
          ./somemodule.nix
          "somemods/global"
          "extras:coolstuff"
        ];
      };

      commonHomeModules = mkOption {
        type = types.listOf types.raw;
        default = [ ];
        example = [
          ./some-homemodule.nix
          "homemods/global"
          "extras:somemodule"
        ];
      };

      commonNixpkgsConfig = mkOption {
        type = types.raw;
        default = { };
        description = ''
          A global default nixpkgs config.
        '';
      };

      commonOverlays = mkOption {
        type = types.listOf types.raw;
        default = [ ];
        description = ''
          A list of global overlays to apply.
        '';
      };

      metaSpecialArgs = mkOption {
        type = types.raw;
        default = { };
        description = ''
          Extra arguments to pass to the meta.nix of every host.
        '';
      };

      homeMetaSpecialArgs = mkOption {
        type = types.raw;
        default = { };
        description = ''
          Extra arguments passed to the meta.nix of every home config.
        '';
      };

      nixosSpecialArgs = mkOption {
        description = "Special args to pass to NixOS systems.";
        type = types.raw;
        default = { };
      };

      homeSpecialArgs = mkOption {
        description = "Special args to pass to Home Manager configs.";
        type = types.raw;
        default = { };
      };

      perTagRules = mkOption {
        description = "Rules for host tags";
        default = { };
        type = types.attrsOf types.submodule {
          options = {
            modules = mkOption {
              description = "Extra modules for hosts under this tag";
              type = types.listOf types.raw;
              default = [ ];
            };

            profiles = mkOption {
              description = "Extra profiles for hosts under this tag";
              type = types.listOf types.raw;
              default = [ ];
            };
          };
        };
      };
    };

  config =
    let
      cfg = config.hostess;
    in
    {
      flake =
        let
          inherit (libHostess.hostess)
            subdirs
            safeImport
            resolveIn
            tryResolveIn
            resolveInList
            compileModulesList
            compileModulesListInList
            deferModule
            collectCommonNixosModules
            collectCommonHomeModules
            compileNamespacedNixosModuleList
            compileNamespacedHomeModuleList
            compileNamespacedProfileList
            ;

          libHostess = lib.extend (import ./lib { inherit config; });

          useHomeManager = !isNull cfg.home-manager;
          useDisko = !isNull cfg.disko;

          nixosModulePaths =
            (optionals (!isNull cfg.nixosModulePath) [ cfg.nixosModulePath ]) ++ cfg.nixosModulePaths;

          homeModulePaths =
            (optionals (!isNull cfg.homeModulePaths) [ cfg.homeModulePaths ]) ++ cfg.homeModulePaths;

          profilePaths = (optionals (!isNull cfg.profilePaths) [ cfg.profilePaths ]) ++ cfg.profilePaths;

          buildHost =
            hostname:
            let
              hostDir = cfg.hostPath + "/${hostname}";
              meta =
                deferModule
                  (safeImport (hostDir + "/meta.nix") {
                    system = "x86_64-linux"; # System.
                    tags = [ ]; # Assigned tags.
                    modules = [ ]; # Modules.
                    profiles = [ ]; # Profiles.
                    useCommonModule = true; # Whether or not to use the common module.
                    useCore = true; # Whether or not to include Hostess' core module.
                    useLibHostess = true; # Whether to use Hostess' library. Necessary for including extra modules.
                    meta = { }; # Extra user defined metadata.
                    home-manager = { }; # Home manager settings.
                  })
                  (
                    {
                      inherit inputs;
                      lib = libHostess;
                    }
                    // cfg.metaSpecialArgs
                  );

              system = meta.system or "x86_64-linux";
              useCommonModule = meta.useCommonModule or true;
              pkgs = import cfg.nixpkgs {
                inherit system;
                config = cfg.commonNixpkgsConfig;
                overlays = cfg.commonOverlays;
              };

              tagRules = map (
                tag:
                cfg.perTagRules."${tag}" or {
                  modules = [ ];
                  profiles = [ ];
                }
              ) (meta.tags or [ ]);

              tagModules = builtins.concatLists (map (r: r.modules or [ ]) tagRules);
              tagProfiles = builtins.concatLists (map (r: r.profiles or [ ]) tagRules);
              # Use lib.lists.unique to prevent doubly including modules/profiles.
              finalModules = lib.lists.unique ((meta.modules or [ ]) ++ tagModules);
              finalProfiles = lib.lists.unique ((meta.profiles or [ ]) ++ tagProfiles);
              namedModules = compileNamespacedNixosModuleList finalModules;
              namedProfiles = compileNamespacedProfileList finalProfiles;

              usingDisko = (!isNull cfg.disko) && (pathExists (hostDir + "/disk.nix"));
              diskoModules = optionals usingDisko [
                cfg.disko.nixosModules.disko
                (safeImport (hostDir + "/disk.nix") { })
              ];

              homeUsers = meta.home-manager.users or [ ];

              buildHomeDesc =
                name:
                let
                  homeDir = (cfg.homePath + "/${name}");

                  userMeta =
                    deferModule
                      (safeImport (homeDir + "/meta.nix") {
                        inherit name;
                        useCommonModule = true;
                        modules = [ ];
                      })
                      (
                        {
                          inherit inputs meta;
                        }
                        // cfg.homeMetaSpecialArgs
                      );

                  homeCommon = optionals (userMeta.useCommonModule or true) (
                    compileNamespacedHomeModuleList cfg.commonHomeModules
                  );

                  homeNamed = compileNamespacedHomeModuleList (userMeta.modules or [ ]);
                in
                {
                  name = userMeta.name or name;
                  rawModule = {
                    imports = homeCommon ++ homeNamed ++ [ (homeDir + "/default.nix") ];
                  };
                };

              homeConfig =
                meta.home-manager or {
                  enable = false;
                  useLibHostess = true; # Will be passed as a special arg, home configs requiring *may* throw errors.
                  useGlobalPkgs = true;
                  useUserPackages = true;
                };

              homeEnable = homeConfig.enable or false;

              homeUserModules = lib.pipe homeUsers [
                (map buildHomeDesc)
                (
                  x:
                  genAttrs' x (d: {
                    name = d.name;
                    value = d.rawModule;
                  })
                )
              ];

              homeModule = optional homeEnable (
                { ... }:
                {
                  home-manager.useGlobalPkgs = homeConfig.useGlobalPkgs or true;
                  home-manager.useUserPackages = homeConfig.useUserPackages or true;
                  home-manager.extraSpecialArgs = {
                    useLibHostess = homeConfig.useLibHostess or true;
                  }
                  // (
                    if (homeConfig.useLibHostess or true) then
                      {
                        lib = libHostess;
                      }
                    else
                      { }
                  );

                  home-manager.users = homeUserModules;
                }
              );
            in
            cfg.nixpkgs.lib.nixosSystem {
              inherit system pkgs;
              modules =
                (optional useCommonModule collectCommonNixosModules)
                ++ namedModules
                ++ namedProfiles
                ++ homeModule
                ++ (optionals useCommonModule cfg.commonNixosModules)
                ++ diskoModules
                ++ (optional (pathExists (hostDir + "/configuration.nix")) (hostDir + "/configuration.nix"));

              specialArgs = {
                useLibHostess = meta.useLibHostess or true;
                meta = meta.meta or { };
              };
            };

          hostNames = if pathExists cfg.hostPath then subdirs cfg.hostPath else [ ];

          nixosConfigurations = builtins.listToAttrs (
            map (name: {
              inherit name;
              value = buildHost name;
            }) hostNames
          );
        in
        {
          inherit nixosConfigurations;
          inherit (config) hostess;
        };
    };
}
