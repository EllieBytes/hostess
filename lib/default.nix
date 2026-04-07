{ cfg, ... }:

final: prev:
let
  inherit (builtins) pathExists;

  nixosModuleRoot = cfg.modulesDir;
  nixosProfileRoot = cfg.profilesDir;

  safeImport = path: default:
  if pathExists path then import path else default;

  moduleOrDirectory = root: res: 
  if pathExists (root + "/${res}") then
  if pathExists (root + "/${res}/default.nix") then
  (root + "/${res}/default.nix")
  else (root + "${res}")
  else (root + "/${res}.nix");

  resolveGlobalModule = m:
  let p = (moduleOrDirectory nixosModuleRoot m); in
  if pathExists p then p else throw ''
    hostess: `resolveGlobalModule ${m}` Module could not be located.
  '';

  resolveGlobalProfile = n:
  let p = (moduleOrDirectory nixosProfileRoot n); in
  if pathExists p then p else throw ''
    hostess: `resolveGlobalProfile ${n}` Profile could not be located.
  '';

  resolveGlobalModules = ml: (map resolveGlobalModule ml);
  resolveGlobalProfiles = pl: (map resolveGlobalProfile pl);
in {
  # lib.hostess.<function> 
  final.hostess = {
    inherit resolveGlobalModule resolveGlobalProfile resolveGlobalModules resolveGlobalProfiles;
    inherit safeImport;
  };
}
