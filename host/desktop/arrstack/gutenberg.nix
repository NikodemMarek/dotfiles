{
  pkgs,
  lib,
  ...
}: let
  booksDir = "/mnt/data/books";
in {
  systemd.services.download-project-gutenberg = {
    enable = true;
    serviceConfig = {
      Wants = ["network-online.target"];
      After = ["network-online.target"];
    };
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = let
        rsync = lib.getExe pkgs.rsync;
      in
        lib.getExe (
          pkgs.writeShellScriptBin "sync-project-gutenberg" ''
            ${rsync} -avHS --timeout 600 --delete --exclude 'cache/' aleph.gutenberg.org::gutenberg ${booksDir}/gutenberg > /dev/null
            ${rsync} -avHS --timeout 600 --delete --exclude '\*/mbt-\*' aleph.gutenberg.org::gutenberg-epub ${booksDir}/gutenberg/.cache/epub
          ''
        );
    };
  };
}
