{
  pkgs,
  lib,
  ...
}: let
  gutenberg-dir = "/mnt/data/books/gutenberg";
  library-dir = "/mnt/data/books/library";

  gutenberg-sync-script = pkgs.writeShellScript "gutenberg-sync" ''
    DEST_DIR="${gutenberg-dir}"

    ${lib.getExe pkgs.rsync} -avHS --timeout 600 --delete --prune-empty-dirs \
      --include="*/" \
      --include="*images-3.epub" \
      --exclude="*" \
      aleph.gutenberg.org::gutenberg-epub "$DEST_DIR"
  '';

  gutenberg-symlink-script = pkgs.writeShellScript "gutenberg-symlink" ''
    SOURCE_DIR="${gutenberg-dir}"
    TARGET_DIR="${library-dir}"

    mkdir -p "$TARGET_DIR"

    find "$TARGET_DIR" -xtype l -delete

    find "$SOURCE_DIR" -name "*-images-3.epub" | while read -r epub_path; do
        TITLE=$(${lib.getExe pkgs.exiftool} -s3 -Title "$epub_path" | sed 's/[/\\:*"<>|]//g' | tr -d '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        AUTHOR=$(${lib.getExe pkgs.exiftool} -s3 -Creator "$epub_path" | sed 's/[/\\:*"<>|]//g' | tr -d '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        SERIES=$(${lib.getExe pkgs.exiftool} -s3 -Series "$epub_path" | sed 's/[/\\:*"<>|]//g' | tr -d '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        [[ -z "$TITLE" ]] && TITLE="Unknown"
        [[ -z "$AUTHOR" ]] && AUTHOR="Unknown"

        # Truncate to fit filesystem limits (255 bytes max filename)
        TITLE="''${TITLE:0:200}"
        AUTHOR="''${AUTHOR:0:100}"
        SERIES="''${SERIES:0:100}"

        if [[ -n "$SERIES" ]]; then
            BOOK_DIR="$TARGET_DIR/$AUTHOR/$SERIES"
        else
            BOOK_DIR="$TARGET_DIR/$AUTHOR"
        fi

        mkdir -p "$BOOK_DIR"

        RELATIVE_PATH=$(${lib.getExe' pkgs.coreutils "realpath"} --relative-to="$BOOK_DIR" "$epub_path")
        ln -sf "$RELATIVE_PATH" "$BOOK_DIR/$TITLE.epub"
    done
  '';
in {
  systemd.services.gutenberg-sync = {
    description = "sync project gutenberg epubs";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig = {
      OnSuccess = "gutenberg-symlink.service";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = gutenberg-sync-script;
      User = "maintenance";
    };
  };

  systemd.services.gutenberg-symlink = {
    description = "generate symlinks for gutenberg";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = gutenberg-symlink-script;
    };
  };

  systemd.timers.gutenberg-sync = {
    description = "run gutenberg sync weekly on monday at 5";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon *-*-* 05:00:00";
      Persistent = true;
    };
  };
}
