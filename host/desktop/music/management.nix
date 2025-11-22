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
    cookies = config.sops.secrets."youtube/cookies.txt".path;
  in [
    (pkgs.writeShellScriptBin "beet" "${beets} $*")

    pkgs.yt-dlp

    (pkgs.writeShellScriptBin "get-yt" ''
      TEMP=$(mktemp -d)
      ${lib.getExe pkgs.yt-dlp} -f bestaudio --extract-audio --audio-format flac --audio-quality 0 --add-metadata --embed-thumbnail -o "$TEMP/%(title)s.%(ext)s" $1
      ${beets} import --write $TEMP
      echo $TEMP
    '')

    (pkgs.writeShellScriptBin "get-yt-single" ''
      TEMP=$(mktemp -d)
      ${lib.getExe pkgs.yt-dlp} -f bestaudio --extract-audio --audio-format flac --audio-quality 0 --add-metadata --embed-thumbnail -o "$TEMP/%(title)s.%(ext)s" $1
      ${beets} import --singletons --write $TEMP
      echo $TEMP
    '')
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
