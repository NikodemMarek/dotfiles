{
  pkgs,
  config,
  lib,
  ...
}: {
  users.users.music = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."users/music/password".path;
    group = "music";
    uid = 2030;
    openssh.authorizedKeys.keyFiles = [
      ../../laptop/user_nikodem_ssh_id_ed25519.pub
    ];
  };

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
  ];

  systemd.tmpfiles.rules = [
    "d /home/music/.config 0740 music music -"
    "d /home/music/.config/beets 0740 music music -"
  ];

  persist.data.directories = [
    {
      directory = "/var/lib/music/beets";
      user = "music";
      group = "music";
      mode = "740";
    }
  ];
}
