{
  description = ''
    A flake-parts module for managing hosts & user configurations automatically.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixkpgs-lib.follows = "nixpkgs";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        imports = [ inputs.devshell.flakeModule ];
        flake.flakeModules.default = ./flake-module.nix;

        systems = [
          "x86_64-linux"
        ];

        perSystem =
          { pkgs, ... }:
          {
            devshells.default = {
              packages = with pkgs; [
                nix
                nixd
                package-version-server
                typos
              ];
            };
          };
      }
    );
}
