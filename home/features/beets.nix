{
    imports = [
        ./yt-dlp.nix
    ];

    programs.beets = {
        enable = true;
        mpdIntegration.enableStats = true;
        mpdIntegration.enableUpdate = true;
        settings = {
            directory = "/home/music/data";
            library = "/home/music/musiclib.db";
            import.move = true;
        };
    };
}
