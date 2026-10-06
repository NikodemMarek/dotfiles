# Secrets contract.
#
# - `secrets.<name>`: set by every module that uses a secret (features and
#   host modules alike), with the file options it needs, e.g.
#   `secrets.users_alice_password.neededForUsers = true;` (`{}` if none).
#   Consumers read only `config.secrets.<name>.path`. Modules that need the
#   same secret must agree on its options, the module system reports clashes.
# - secretspec.toml (repo root) is the inventory: the profile named after the
#   host lists every secret it has, as uppercased names. Keys that only feed a
#   `composed` secret are inputs and are not part of it.
#
# Names are flat lowercase snake_case, matching `^[a-z0-9_]+$`: no `/` or `-`.
# That keeps them flat keys in the provider's store.
#
# Evaluation fails if the used secrets and the profile diverge, or a name is
# invalid. The check runs in `apply`, i.e. on the first read of
# `config.secrets`: an `assertions` entry is not reliable, since other modules'
# assertions (users-groups, k3s) dereference `config.secrets.<name>.path` and
# would abort first with "attribute missing".
#
# The provider (imported by host/features/global/default.nix) must make each
# file available at `path` with the requested owner, group and mode.
{
  lib,
  config,
  options,
  ...
}: let
  inherit (lib) mkOption literalExpression;
  inherit (lib.types) attrsOf submodule str bool;

  secret = submodule ({
    name,
    config,
    ...
  }: {
    options = {
      owner = mkOption {
        type = str;
        default = "root";
      };
      group = mkOption {
        type = str;
        default = "root";
      };
      mode = mkOption {
        type = str;
        default = "0400";
      };
      neededForUsers = mkOption {
        description = "Secret must exist before users are created";
        type = bool;
        default = false;
      };
      path = mkOption {
        type = str;
        default =
          if config.neededForUsers
          then "/run/secrets-for-users/${name}"
          else "/run/secrets/${name}";
        defaultText = literalExpression ''"/run/secrets/''${name}" (or /run/secrets-for-users if neededForUsers)'';
      };
    };
  });

  # The host's inventory: its secretspec.toml profile, minus the keys that only
  # feed a `composed` secret (they are never written to the sops file).
  host = config.networking.hostName;
  profile = (builtins.fromTOML (builtins.readFile ../../secretspec.toml)).profiles.${host} or {};
  composed = lib.mapAttrsToList (_: spec: spec.composed or "") profile;
  isInput = key: lib.any (lib.hasInfix "\${${key}}") composed;
  keys = lib.filter (key: !isInput key) (lib.attrNames profile);
  inventory = map lib.toLower keys;

  # Files whose `secrets` definition mentions secret `name`
  definedIn = name:
    lib.concatMapStringsSep ", " (def: def.file)
    (lib.filter (def: def.value ? ${name}) options.secrets.definitionsWithLocations);

  # Every way the used secrets (`used`) and the inventory diverge.
  # Use the apply argument, never config.secrets here (infinite recursion).
  divergences = used: let
    invalid =
      map (name: "\"${name}\" ${lib.optionalString (used ? ${name}) "in ${definedIn name} "}is not a valid secret name (lowercase letters, digits and _ only)")
      (lib.filter (name: builtins.match "[a-z0-9_]+" name == null)
        (lib.unique (lib.attrNames used ++ inventory)));

    missing =
      map (name: "\"${name}\" is used by ${definedIn name} but missing from profile ${host} in secretspec.toml")
      (lib.filter (name: !(lib.elem name inventory)) (lib.attrNames used));

    unused =
      map (key: "\"${key}\" in profile ${host} of secretspec.toml is not used by any module")
      (lib.filter (key: !(used ? ${lib.toLower key})) keys);
  in
    invalid ++ missing ++ unused;
in {
  options.secrets = mkOption {
    description = "Secrets the host's modules use, provided as files. Names must match the host's profile in secretspec.toml";
    default = {};
    type = attrsOf secret;
    apply = used: let
      errors = divergences used;
    in
      lib.throwIf (errors != []) ''
        Secrets and secretspec.toml diverge:
        ${lib.concatMapStringsSep "\n" (e: "- ${e}") errors}''
      used;
  };
}
