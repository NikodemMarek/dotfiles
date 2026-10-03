{
  persist = import ./persist.nix;
  secrets = import ./secrets.nix;
  battery-notifier = import ./battery-notifier.nix;
}
