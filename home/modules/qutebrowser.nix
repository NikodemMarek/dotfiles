{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.qutebrowser = {
    enable = true;
    extraConfig = ''
      config.load_autoconfig(False)

      config.set('content.cookies.accept', 'all', 'chrome-devtools://*')
      config.set('content.cookies.accept', 'all', 'devtools://*')

      config.set('content.images', True, 'chrome-devtools://*')
      config.set('content.images', True, 'devtools://*')

      c.content.javascript.clipboard = 'access'

      config.set('content.javascript.enabled', True, 'chrome-devtools://*')
      config.set('content.javascript.enabled', True, 'devtools://*')
      config.set('content.javascript.enabled', True, 'chrome://*/*')
      config.set('content.javascript.enabled', True, 'qute://*/*')

      config.set('content.local_content_can_access_remote_urls', True, 'file://${config.home.homeDirectory}/.local/share/qutebrowser/userscripts/*')
      config.set('content.local_content_can_access_file_urls', False, 'file://${config.home.homeDirectory}/.local/share/qutebrowser/userscripts/*')

      config.set('content.register_protocol_handler', True, 'https://mail.google.com?extsrc=mailto&url=%25s')
    '';
  };
}
