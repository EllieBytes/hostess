# Hostess

hostess is a flake-parts module designed for use with colmena.

## Example

```Nix
# In flake.nix
# ...

  imports = [ hostess.flakeModules.default ];

  hostess = {
    hostsDir = ./hosts;
    usersDir = ./users;
  };
# ...
```

```
# In hosts/myhost/meta.nix

{ ... }:

{
  targetHost = "10.42.0.6";
  targetUser = "root";
  tags = [ "server" ];
}
```

Deploy with `colmena apply --at @server` to apply to 'myhost' and every host on the network under the tag 'server'.

Rules can also be applied to tags via `hostess.perTag`
