{
  description = ''
    An easy enterprise grade host management solution.
    designed for use with colmena
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } ({ ... }: {
    flake.flakeModules.default = ./flake-module.nix;
  });
}
