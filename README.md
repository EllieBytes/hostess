# Hostess

hostess is a flake-parts module designed for easy host management.

## Example

```Nix
# In flake.nix
# ...

  imports = [ hostess.flakeModules.default ];

  hostess = {
    nixpkgs = inputs.nixpkgs;
    home-manager = inputs.home-manager;

    # Scanned for host configs.
    hostsDir = ./hosts;
    # Scanned for home-manager configs.
    usersDir = ./users;
    # Scanned for NixOS modules
    modulesDir = ./modules/nixos;
    # Scanned for NixOS profiles
    profilesDir = ./profiles/nixos;
    # Scanned for HM modules
    homeModulesDir = ./modules/home;
    # Scanned for HM profiles
    homeProfilesDir = ./profiles/home;
    # NixOS modules to apply to all hosts.
    commonNixosModules = [ ./profiles/nixos/base.nix ];

    perTagRules = {
      server = {
        profiles = [ "base/server" ];
      };
    };
  };
# ...
```

```
# In hosts/myhost/meta.nix

{ ... }:

{
  modules = [ "software/jellyfin" ];
  tags = [ "server" ];
}
```
