#!/usr/bin/env bash

# I could separate out each function type in new folders if I wanted to

# NETWORK

private_ip() {
  ip route get 1 | head -1 | cut -d' ' -f7
}

public_ip() {
  curl -s https://ipinfo.io/ip -w "\n"
}

# factored out in case I switch password managers
ssh_pass() {
  bw get password SSH
}

update_dot() {
  cd /etc/nixos/ || return
  git add home.nix configuration.nix flake.nix
  git commit -m "$1"
  git push <<< "$(ssh_pass)"
  sudo nixos-rebuild switch
}
