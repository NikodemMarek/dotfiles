# Secrets contract.
#
# - `secrets.<name>`: the host's inventory, every secret it has and the
#   owner/group/mode/... of its file. Set only in host/<host>/secrets.nix.
# - `secretsRequired.<name>`: set by every module that uses a secret (features
#   and host modules alike), mapped to the secret options it relies on, e.g.
#   `secretsRequired.users_alice_password.neededForUsers = true;` (`{}` if
#   none). Consumers read only `config.secrets.<name>.path`.
#
# Names are flat lowercase snake_case, matching `^[a-z0-9_]+$`: no `/` or `-`.
# That keeps them flat keys in the provider's store.
#
# Evaluation fails if the two diverge, or a name is invalid. The check runs in
# `apply`, i.e. on the first read of `config.secrets`: an `assertions` entry is
# not reliable, since other modules' assertions (users-groups, k3s)
# dereference `config.secrets.<name>.path` and would abort first with
# "attribute missing".
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
  inherit (lib.types) attrsOf submodule str bool anything;

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

  # Files whose definition of option `opt` mentions secret `name`
  definedIn = opt: name:
    lib.concatMapStringsSep ", " (def: def.file)
    (lib.filter (def: def.value ? ${name}) opt.definitionsWithLocations);

  # Every way the inventory (`declared`) and the requirements diverge.
  # Use the apply argument, never config.secrets here (infinite recursion).
  divergences = declared: let
    required = config.secretsRequired;
    requiredBy = definedIn options.secretsRequired;
    declaredIn = definedIn options.secrets;

    invalid =
      map (name: "\"${name}\" in ${lib.concatStringsSep ", " (lib.filter (f: f != "") [(declaredIn name) (requiredBy name)])} is not a valid secret name (lowercase letters, digits and _ only)")
      (lib.filter (name: builtins.match "[a-z0-9_]+" name == null)
        (lib.unique (lib.attrNames declared ++ lib.attrNames required)));

    missing =
      map (name: "\"${name}\" is required by ${requiredBy name} but not declared in host/<host>/secrets.nix")
      (lib.attrNames (removeAttrs required (lib.attrNames declared)));

    unused =
      map (name: "\"${name}\" is declared in ${declaredIn name} but nothing requires it")
      (lib.attrNames (removeAttrs declared (lib.attrNames required)));

    mismatched = lib.concatLists (lib.mapAttrsToList (name: wants:
      lib.concatLists (lib.mapAttrsToList (opt: want:
        if !(declared.${name} ? ${opt})
        then ["secretsRequired.\"${name}\".${opt} in ${requiredBy name} is not a secret option"]
        else
          lib.optional (declared.${name}.${opt} != want)
          "secrets.\"${name}\".${opt} is ${builtins.toJSON declared.${name}.${opt}} in ${declaredIn name}, but ${requiredBy name} requires ${builtins.toJSON want}")
      wants))
    (builtins.intersectAttrs declared required));
  in
    invalid ++ missing ++ unused ++ mismatched;
in {
  options.secrets = mkOption {
    description = "Every secret this host has, provided as files. Set only in host/<host>/secrets.nix";
    default = {};
    type = attrsOf secret;
    apply = declared: let
      errors = divergences declared;
    in
      lib.throwIf (errors != []) ''
        Secrets inventory and requirements diverge:
        ${lib.concatMapStringsSep "\n" (e: "- ${e}") errors}''
      declared;
  };

  options.secretsRequired = mkOption {
    description = ''
      Secrets a module uses, each mapped to the `secrets.<name>` option values
      it relies on (`{}` for none). Every entry must be declared in `secrets`
      with matching values, and every declared secret must be required here.
    '';
    default = {};
    type = attrsOf (attrsOf anything);
    example = literalExpression ''{ users_alice_password.neededForUsers = true; }'';
  };
}
