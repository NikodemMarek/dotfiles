{
  services.declarative-jellyfin = {
    enable = true;
    serverId = "70b7acd594f643c6b8bbbe517322d6f0";

    libraries = {
      Movies = {
        enabled = true;
        contentType = "movies";
        pathInfos = ["/mnt/movies"];
        typeOptions.Movies = {
          metadataFetchers = [
            "The Open Movie Database"
            "TheMovieDb"
          ];
          imageFetchers = [
            "The Open Movie Database"
            "TheMovieDb"
          ];
        };
      };
      Shows = {
        enabled = true;
        contentType = "tvshows";
        pathInfos = ["/mnt/shows"];
      };
      Music = {
        enabled = true;
        contentType = "music";
        pathInfos = ["/mnt/music"];
      };
      Books = {
        enabled = true;
        contentType = "books";
        pathInfos = ["/mnt/books"];
      };
    };

    users = {
      admin = {
        mutable = false;
        password = "1234";
        # hashedPasswordFile = ../tests/example_hash.txt;
        permissions.isAdministrator = true;
      };
      nikodem = {
        mutable = false;
        password = "1234";
        # hashedPasswordFile = ../tests/example_hash.txt;
        permissions = {
          isAdministrator = false;
          enableAllFolders = true;
        };
      };
    };

    apikeys = {
      jellyseerr = {
        key = "1759054054948de10364d-f4a8-4b8b-8143-259f5867fe11";
        # keyPath = ../tests/example_apikey.txt;
      };
    };
  };
}
