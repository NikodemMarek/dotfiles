# `bw` with its data dir (login state, vault cache) moved out of $HOME.
# With the default `dataDir = null` this is upstream bitwarden-cli unchanged.
{
  lib,
  symlinkJoin,
  makeWrapper,
  bitwarden-cli,
  dataDir ? null,
}:
if dataDir == null
then bitwarden-cli
else
  assert lib.assertMsg (builtins.match "/[A-Za-z0-9._/-]*" dataDir != null) "bitwarden-cli: dataDir must be an absolute path of [A-Za-z0-9._/-]";
    symlinkJoin {
      inherit (bitwarden-cli) name meta;
      paths = [bitwarden-cli];
      nativeBuildInputs = [makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/bw --set BITWARDENCLI_APPDATA_DIR ${dataDir}
      '';
    }
