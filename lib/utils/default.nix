# lib/default.nix
{ lib, pkgs, secretsPath }:
rec {
  secrets = rec {
    path = secretsPath;
    
    # Helper to get path to a secret file
    file = secretName: path + "/${secretName}.age";
    
    # Helper to create a basic secret with common defaults
    mkSecret = secretName: attrs: {
      file = file secretName;
    } // attrs;
    
    # Helper for secrets that need specific ownership
    mkOwnedSecret = secretName: owner: group: mkSecret secretName {
      inherit owner group;
    };
  };
  
  # Caddy helpers
  caddy = rec {
    # Generate Cloudflare DNS TLS block
    cloudflareTLS = resolvers: ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        ${lib.optionalString resolvers "resolvers 1.1.1.1"}
      }
    '';
    
    # Generate reverse proxy line
    reverseProxy = port: extraConfig: ''
      reverse_proxy localhost:${toString port}${lib.optionalString (extraConfig != "") " {\n${extraConfig}\n}"}
    '';
    
    # Complete vhost config with Cloudflare TLS + reverse proxy
    mkServiceVHost = { port, resolvers ? true, extraProxyConfig ? "" }: ''
      ${cloudflareTLS resolvers}
      ${reverseProxy port extraProxyConfig}
    '';
  };
}
