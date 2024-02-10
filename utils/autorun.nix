# Function that creates a autorun service for user, that runs once, after display manager starts.
{ name, script, path ? [] }:
    { pkgs, lib, username, ... }: {
        systemd.user.services.${name} = {
            Unit = {
                Description = "autorun script for ${name}";
                After = [ "graphical-session.target" ];
            };
            Install = {
                WantedBy = [ "graphical-session.target" ];
            };
            Service = {
                Type = "forking";
                ExecStart = "${pkgs.writeShellScript "autorun-${name}" ''
                    #!${pkgs.stdenv.shell}
                    # FIXME: This is the dirtiest solution ever, maybe there is PATH variable in home manager?
                    PATH=$PATH:/home/${username}/.nix-profile/bin:/nix/profile/bin:/home/${username}/.local/state/nix/profile/bin:/etc/profiles/per-user/${username}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:${lib.makeBinPath path}

                    ${script}
                ''}";
            };
        };
    }
