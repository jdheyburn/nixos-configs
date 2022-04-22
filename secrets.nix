let
  deeHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIozTzNnp+KQAwlMUdJuIcvuQmM+Dz5wlB7H15Qx3iZT jdheyburn@dee";
in {
 "secrets/cloudflare-api-token.age".publicKeys = [ deeHost ];
}

