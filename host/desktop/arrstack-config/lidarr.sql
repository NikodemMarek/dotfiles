-- Add qBittorrent as a download client
INSERT INTO DownloadClients VALUES(1,1,'qBittorrent','QBittorrent',unistr('{\u000a  "host": "127.0.0.1",\u000a  "port": 6969,\u000a  "useSsl": false,\u000a  "movieCategory": "radarr",\u000a  "recentMoviePriority": 0,\u000a  "olderMoviePriority": 0,\u000a  "initialState": 0,\u000a  "sequentialOrder": false,\u000a  "firstAndLast": false,\u000a  "contentLayout": 0\u000a}'),'QBittorrentSettings',1,1,1,'[]');

-- Add The Pirate Bay (Prowlarr) as an indexer
-- INSERT INTO Indexers VALUES(1,'The Pirate Bay (Prowlarr)','Torznab',unistr('{\u000a  "minimumSeeders": 1,\u000a  "seedCriteria": {},\u000a  "rejectBlocklistedTorrentHashesWhileGrabbing": false,\u000a  "requiredFlags": [],\u000a  "baseUrl": "http://127.0.0.1:9696/1/",\u000a  "apiPath": "/api",\u000a  "apiKey": "c84cd4955ce246f7a8ad8be5a93c3667",\u000a  "categories": [\u000a    2000,\u000a    2020,\u000a    2040,\u000a    2060,\u000a    2030,\u000a    2045\u000a  ],\u000a  "multiLanguages": [],\u000a  "failDownloads": [],\u000a  "removeYear": false\u000a}'),'TorznabSettings',1,1,1,25,'[]',0);

-- Add default root folder
INSERT INTO RootFolders VALUES(1,'/mnt/data/music','Music',1,1,0,'[]',0);

-- Add default naming config
INSERT INTO NamingConfig VALUES(1,1,'{Artist Name}',1,'{Album Title} ({Release Year})/{Artist Name} - {Album Title} - {track:00} - {Track Title}','{Album Title} ({Release Year})/{Medium Format} {medium:00}/{Artist Name} - {Album Title} - {track:00} - {Track Title}',4);
