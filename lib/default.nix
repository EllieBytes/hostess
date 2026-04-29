{ config, ... }:

final: prev:
let
  inherit (builtins)
    attrNames
    readDir
    pathExists
    tryEval
    filter
    length
    elemAt
    isString
    isPath
    isFunction
    isAttrs
    ;

  trace = a: b: builtins.traceVerbose ("hostess: " + a) b;

  inherit (prev) filterAttrs;
  cfg = config.hostess;

  subdirs = dir: attrNames (filterAttrs (_: t: t == "directory")) (readDir dir);
  safeImport =
    path: default:
    if pathExists path then
      import path
    else
      trace "safeImport: ${path} not found using default." default;

  resolveIn =
    root: name:
    let
      base = root + "/${name}";
    in
    if pathExists "${base}.nix" then
      "${base}.nix"
    else if pathExists (base + "/default.nix") then
      (base + "/default.nix")
    else
      throw "Could not resolve ${name} within ${root}";

  tryResolveIn = root: name: tryEval (resolveIn root name);

  resolveInList =
    roots: name:
    let
      finals = prev.pipe roots [
        (map (r: tryResolveIn r name))
        (filter (r: (r.success or false) == true))
        (map (r: r.value or null))
        (filter (v: !(isNull v)))
      ];
    in
    if (length finals) > 1 then
      trace
        ''
          resolveInList: found multiple artifacts.
          ?: ${finals}
        ''
        (
          builtins.warn ''
            Module ${name} was found within multiple roots.
            Using first module: ${elemAt finals 0}
          '' (elemAt finals 0)
        )
    else
      elemAt finals 0;

  compileModulesList =
    root: names:
    let
      pathsList = filter (r: !(isString r)) names;
      modsList = filter (r: isString r) names;
      modsListResolved = map (resolveIn root) modsList;
    in
    pathsList ++ modsListResolved;

  compileModulesListInList =
    roots: names:
    let
      pathsList = filter (r: !(isString r)) names;
      modsList = filter (r: isString r) names;
      modsListResolved = map (resolveInList roots) modsList;
    in
    pathsList ++ modsListResolved;

  resolveNixosModule = name: resolveInList cfg.nixosModulePaths name;
  resolveProfiles = name: resolveInList cfg.nixosProfilePaths name;
  resolveHomeModule = name: resolveInList cfg.homeModulePaths name;

  namespacedResolver =
    resv:
    let
      l = filter (x: x != [ ]) (builtins.split ":" resv);
    in
    {
      namespace = if length l > 1 then (elemAt l 0) else "";
      name = if length l > 1 then (elemAt l 1) else (elemAt l 0);
    };

  evalEnum =
    e: c: if builtins.elem c e then c else throw "Invalid enum state ${c} must be one of ${e}";

  # Behaves like a switch statement in any other language.
  switch = c: fns: fns."${c}" or null;

  enumStates =
    e: c: fns:
    let
      case = evalEnum e c;
    in
    switch case fns;

  getProfilePaths =
    namesp:
    if namesp == "" then
      (prev.optionals (!isNull cfg.profilePath) [ cfg.profilePath ]) ++ cfg.profilePaths
    else
      cfg.namespaces."${namesp}".profilePaths;

  getNixosModulePaths =
    namesp:
    if namesp == "" then
      (prev.optionals (!isNull cfg.nixosModulePath) [ cfg.nixosModulePath ]) ++ cfg.nixosModulePaths
    else
      cfg.namespaces."${namesp}".nixosModulePaths;

  getHomeModulePaths =
    namesp:
    if namesp == "" then
      (prev.optionals (!isNull cfg.homeModulePath) [ cfg.homeModulePath ]) ++ cfg.homeModulePaths
    else
      cfg.namespaces."${namesp}".homeModulePaths;

  deferModule =
    m: a:
    if isFunction m then
      m a
    else if isAttrs m then
      m
    else if isPath m || isString m then
      deferModule (import m) a
    else
      throw "Invalid type.";

  resolveNamespacedResolver =
    pf: resv:
    let
      broken = namespacedResolver resv;
      paths = pf broken.namespace;
    in
    resolveInList paths broken.name;

  compileNamespacedResolverList = map resolveNamespacedResolver;

  compileNamespacedNixosModuleList = map (resolveNamespacedResolver getNixosModulePaths);
  compileNamespacedHomeModuleList = map (resolveNamespacedResolver getHomeModulePaths);

  compileNamespacedProfileList = map (resolveNamespacedResolver getProfilePaths);

  collectCommonModulesIn = map (x: prev.optional (pathExists x + "/common.nix") (x + "/common.nix"));

  # Collects all common modules, only uses this namespace!.
  collectCommonNixosModules = collectCommonModulesIn (
    cfg.nixosModulePaths ++ (prev.optional (!isNull cfg.nixosModulePath) cfg.nixosModulePath)
  );

  collectCommonHomeModules = collectCommonModulesIn (
    cfg.homeModulePaths ++ (prev.optional (!isNull cfg.homeModulePath) cfg.homeModulePath)
  );
in
{
  # lib.hostess.<function>
  final.hostess = {
    inherit
      subdirs
      safeImport
      resolveIn
      tryResolveIn
      resolveInList
      compileModulesList
      compileModulesListInList
      deferModule
      compileNamespacedResolverList
      getHomeModulePaths
      getNixosModulePaths
      getProfilePaths
      enumStates
      switch
      collectCommonModulesIn
      collectCommonNixosModules
      collectCommonHomeModules
      compileNamespacedNixosModuleList
      compileNamespacedHomeModuleList
      compileNamespacedProfileList
      ;
  };
}
