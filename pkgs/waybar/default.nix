{pkgs, ...}:
pkgs.symlinkJoin {
  name = "waybar";
  paths = [pkgs.waybar];
  buildInputs = [pkgs.makeWrapper];
  postBuild = let
    tailscale-status = pkgs.writeShellScriptBin "tailscale-status" ''
      tailscale status --json | jq --unbuffered --compact-output -c '
        [ .Peer[] | select(.ExitNode == true) ] as $node
        | if ($node | length > 0) then
            {
              "text": $node[0].HostName,
              "alt": $node[0].TailscaleIPs[0],
              "tooltip": "\($node[0].HostName) (\($node[0].TailscaleIPs[0]))",
              "class": "exit-node-on",
              "percentage": 100
            }
          else
            {
              "text": "No Exit Node",
              "alt": "none",
              "tooltip": "Standard Routing",
              "class": "exit-node-off",
              "percentage": 0
            }
          end'
    '';
    tailscale-toggle = pkgs.writeShellScriptBin "tailscale-toggle" ''
      STATUS=$(tailscale-status | jq .percentage)
      if [ $STATUS -ge 50 ]; then
        tailscale up --operator=$USER --accept-routes --exit-node-allow-lan-access=false --exit-node=
      else
        EXIT_NODE_IP=$(host triss | awk '{print $4}')
        tailscale up --operator=$USER --accept-routes --exit-node-allow-lan-access=true --exit-node=$EXIT_NODE_IP
      fi
    '';
    extraPkgs = [
      pkgs.tailscale
      tailscale-status
      tailscale-toggle
    ];
  in ''
    wrapProgram $out/bin/waybar \
        --suffix PATH : ${pkgs.lib.strings.makeBinPath extraPkgs} \
        --add-flags "--config $out/config/waybar/config.json" \
        --add-flags "--style $out/config/waybar/style.css"

    mkdir -p $out/config/waybar
    cp ${./config.json} $out/config/waybar/config.json
    cp ${./colors.css} $out/config/waybar/colors.css
    cp ${./style.css} $out/config/waybar/style.css
  '';
}
