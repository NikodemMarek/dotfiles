{
  lib,
  glab,
  formats,
  symlinkJoin,
  makeWrapper,
  runCommand,
  writeShellScript,
  coreutils,
  diffutils,
  # merged (recursively) over ./config.nix, e.g. extra hosts
  extraConfig ? {},
  # where glab reads its config from; shell-expanded at runtime
  dataDir ? "$HOME/.local/share/glab",
}: let
  yaml = formats.yaml {};

  config = runCommand "glab-config" {} ''
    mkdir -p "$out"
    cp ${yaml.generate "config.yml" (lib.recursiveUpdate (import ./config.nix) extraConfig)} "$out/config.yml"
  '';

  # glab refuses config files that are not mode 600, so they can't be store
  # links: they are copied over on every launch instead (changes glab makes to
  # them are dropped; tokens live in the keyring, see ./config.nix).
  # Sourced from the makeWrapper script (`bash -e`), hence the `|| true`.
  preamble = writeShellScript "glab-preamble" ''
    __glab_copy() {
      local src="${config}/$1" dst="$GLAB_CONFIG_DIR/$1"
      ${diffutils}/bin/cmp -s "$src" "$dst" && return 0
      # atomic replace: never leaves $dst half-written for a concurrent launch
      ${coreutils}/bin/install -m600 "$src" "$dst.tmp.$$" \
        && ${coreutils}/bin/mv -T "$dst.tmp.$$" "$dst" \
        || ${coreutils}/bin/rm -f "$dst.tmp.$$"
    }

    __glab_setup() {
      export GLAB_CONFIG_DIR="''${GLAB_CONFIG_DIR:-${dataDir}}"
      ${coreutils}/bin/mkdir -p "$GLAB_CONFIG_DIR"
      __glab_copy config.yml
    }

    __glab_setup || true
    unset -f __glab_copy __glab_setup
  '';
in
  symlinkJoin {
    name = "glab-${glab.version}";
    paths = [glab];
    nativeBuildInputs = [makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/glab \
        --run "source ${preamble}"
    '';

    passthru = {
      inherit config;
      inherit (glab) version;
    };

    meta =
      glab.meta
      // {
        mainProgram = "glab";
      };
  }
