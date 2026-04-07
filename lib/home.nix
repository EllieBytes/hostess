{ cfg
, ... }:

final: prev:
let
  inherit (builtins) pathExists;

  homeModuleRoot = cfg.homeModulesDir;
  homeProfileRoot = cfg.homeProfilesDir;

  safeImport = path: default:
  if pathExists path then import path else default;

  moduleOrDirectory = root: res: 
  if pathExists (root + "/${res}") then
  if pathExists (root + "/${res}/default.nix") then
  (root + "/${res}/default.nix")
  else (root + "${res}")
  else (root + "/${res}.nix");

  resolveGlobalModule = m:
  let p = (moduleOrDirectory homeModuleRoot m); in
  if pathExists p then p else throw ''
    hostess: `resolveGlobalModule ${m}` Module could not be located.
  '';

  resolveGlobalProfile = n:
  let p = (moduleOrDirectory homeProfileRoot n); in
  if pathExists p then p else throw ''
    hostess: `resolveGlobalProfile ${n}` Profile could not be located.
  '';

  resolveGlobalModules = ml: (map resolveGlobalModule ml);
  resolveGlobalProfiles = pl: (map resolveGlobalProfile pl);
in {
  final.hostess = {
    inherit resolveGlobalModule resolveGlobalProfile resolveGlobalModules resolveGlobalProfiles;
    inherit safeImport;
  };
}
