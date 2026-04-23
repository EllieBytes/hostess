{
  description = ''
    A flake-parts module for managing hosts & user configurations automatically. 
  '';

  outputs = { ... }:
    flakeModule = ./flake-modules/hostess.nix;
  });
}
