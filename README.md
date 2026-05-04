# Hostess

hostess is a flake-parts module designed for easy host management.

## Word of warning.

This module may undergo rewrites. please keep watch & be wary. I will retain all existing function as well as try to keep your setups intact. If things become probelmatic I will deprecate them with 
Up to 6 month warning before complete deprecation.

## Current problems on the fixin' block.

* Inability to extend standard library via specialArgs
  *   Can possibly be fixed with lib extension logic (maybe map / mergeAttrs ?)
* Inability to output mulitple types.
  *   This framework was intended to be able to output ISOs, Images, & containers. it doesn't
* Meta is unsafe & unchecked. Module logic is off.
  *   Strengthen module support & enforce meta defaults / validation.
* Secrets unmanaged.
  *   Allow sops or age to be used.
* Input injection is clunky.
  *   Still looking for better to be honest. maybe include everything and then allow host meta to turn off things.
* Nixpkgs channels not supported.
  *   Hosts should be able to follow user-specified channels.
* The flake-parts reacharound.
  *   Expose our own mkFlake wrapper.
* `deploy-rs`, `colmena`, `nixops`, etc...
  *   This is difficult, ill hold a concensus on the 3 most popular, those will get first-class support.
* Allow custom builders.
  *   Extra builder specification, might kill 2 birds with one stone working on ISO, image, and container support.

## Usage.

Simply feed hostess some basic information in your `flake.nix`. After this is done hostess will
automatically scan for hosts, home-manager configs, modules, profiles, and disko configs.

Hostess is designed to make those large scale setups easy to manage, using a basic convention to keep your `flake.nix` minimal
and allow you to focus on your real configurations.

#### Example structure.
```
.
L flake.nix          : Your flake.nix
L hosts/             : hostess.hostsDir
| L host-a/          : host, exposed as nixosConfigurations.host-a
| | L default.nix    : entry point for host config
| | L disk.nix       : defines disko configuration.
| | L meta.nix       : defines metadata for hostess.
| L host-b/
| | L default.nix
| | L meta.nix
L home/              : hostess.usersDir
| L user-a/          : user-a, accessible by host meta, and outputs.homeConfigurations.user-a
| | L default.nix
| | L meta.nix
L modules/           
| L nixos/           : NixOS modules are searched here.
| | L common.nix
| L home/            : Home modules are searched here.
| | L common.nix
L profiles/          : Same as above, but for profiles.
| L nixos/
| | L common.nix
| L home/
| | L common.nix
```

## Modules.

Hostess expects all modules to be in one standard location (defined by `hostess.modulesDir`).
Resolving a global module is simple, take this for example `"hardware/bluetooth"`.

Hostess will now check in your module directory. let's use this example one.

```
.
L hardware/
  L bluetooth.nix
```

Hostess will take the directory `hardware/bluetooth.nix`. if `hardware/bluetooth` happens to be a directory.
`hardware/bluetooth/default.nix` will be imported.

## Host metadata.

Hosts should have a meta.nix in the root of their config directory.

## `lib.hostess`

hostess exposes an extended nixpkgs library to every host, allowing hosts to access the global module system directly.

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

```Nix
# In hosts/myhost/meta.nix

{ ... }:

{
  modules = [ "software/jellyfin" ];
  tags = [ "server" ];
}
```
