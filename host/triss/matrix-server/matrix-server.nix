{
  services = {
    matrix-tuwunel = {
      enable = true;
      user = "root";
      settings = {
        global = {
          port = [6167];
          server_name = "matrix.nkmrk.com";
          allow_federation = false;
          trusted_servers = [];
          allow_encryption = true;
          allow_registration = true;
          # FIXME: File does not work, because of tuwunel bug?
          # registration_token_file = "/run/credentials/@system/registration_token_file";
        };
      };
    };

    mautrix-meta.instances = {
      messenger = {
        enable = true;
        settings = {
          network.mode = "messenger";
          homeserver.domain = "matrix.nkmrk.com";
          homeserver.address = "http://localhost:6167";

          bridge = {
            permissions = {
              "@nikodem:matrix.nkmrk.com" = "admin";
            };

            encryption = {
              allow = true;
              default = true;
              require = true;

              delete_keys = {
                dont_store_outbound = true;
                ratchet_on_decrypt = true;
                delete_fully_used_on_decrypt = true;
                delete_prev_on_new_session = true;
                delete_on_device_delete = true;
                periodically_delete_expired = true;
                delete_outdated_inbound = true;
              };

              verification_levels = {
                receive = "cross-signed-tofu";
                send = "cross-signed-tofu";
                share = "cross-signed-tofu";
              };
            };
          };

          appservice = {
            id = "messenger";
            address = "http://localhost:29319";
            bot = {
              username = "messengerbot";
              displayname = "Messenger bridge bot";
              avatar = "mxc://maunium.net/ygtkteZsXnGJLJHRchUwYWak";
            };
          };
        };
      };
    };
  };
}
