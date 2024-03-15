{ pkgs, ... }: {
    users.groups.music = {};
    systemd.tmpfiles.rules = [
        "d /home/music 0774 root music -"
        "d /home/music/data 0774 root music -"
        "f /home/music/musiclib.db 0774 root music -"
        "f /home/music/config.yaml 0444 root root - directory: /home/music/data\\nimport:\\n  move: true\\nlibrary: /home/music/musiclib.db\\n" # TODO: move to nix store
    ];
}
