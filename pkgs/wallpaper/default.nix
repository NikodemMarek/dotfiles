{runCommand}:
# The wallpaper image: $out is the file itself.
runCommand "wallpaper.png" {} "cp ${./background.png} $out"
