# Generic glab config, rendered to config.yml (pkgs/glab). Copied to
# $GLAB_CONFIG_DIR on every launch, local edits are lost. Tokens live in the
# OS keyring (use_keyring), under "glab:<host>:token". Updates come from nix,
# hence check_update: false. Extra hosts go in `extraConfig`.
{
  git_protocol = "ssh";
  glamour_style = "dark";
  check_update = false;
  display_hyperlinks = false;
  host = "gitlab.com";
  no_prompt = false;
  telemetry = false;
  hosts."gitlab.com" = {
    api_protocol = "https";
    api_host = "gitlab.com";
    container_registry_domains = "gitlab.com,gitlab.com:443,registry.gitlab.com";
    custom_headers = [];
    use_keyring = true;
  };
}
