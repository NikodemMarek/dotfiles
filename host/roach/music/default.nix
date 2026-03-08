{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = let
    beets = "${lib.getExe pkgs.beets} -c ${./beets.yaml}";

    download-yt = pkgs.writeShellScriptBin "download-yt" ''
      ${lib.getExe pkgs.yt-dlp} -f bestaudio --extract-audio --audio-format flac --audio-quality 0 --add-metadata --embed-thumbnail -o "$1/%(title)s.%(ext)s" $2
    '';
    download-yt-restricted = pkgs.writeShellScriptBin "download-yt-restricted" ''
      if [ ! -f /tmp/yt-cookies.txt ]; then
        echo "Cookie file /tmp/yt-cookies.txt not found! Please create it with your browser cookies from youtube."
        exit 1
      fi
      ${lib.getExe pkgs.yt-dlp} --cookies /tmp/yt-cookies.txt -f bestaudio --extract-audio --audio-format flac --audio-quality 0 --add-metadata --embed-thumbnail -o "$1/%(title)s.%(ext)s" $2
    '';

    get-yt-album = pkgs.writeShellScriptBin "get-yt-album" ''
      TEMP=$(mktemp -d)
      ${lib.getExe download-yt} $TEMP $1
      ${beets} import --write $TEMP
      echo $TEMP
    '';
  in [
    (pkgs.writeShellScriptBin "beet" "${beets} $*")

    pkgs.yt-dlp

    download-yt
    download-yt-restricted

    get-yt-album

    pkgs.ffmpeg
  ];

  systemd.tmpfiles.rules = [
    "d /home/maintenance/.config 0740 maintenance users -"
    "d /home/maintenance/.config/beets 0740 maintenance users -"
  ];
}
