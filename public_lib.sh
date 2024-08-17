#!/usr/bin/env bash

# I separate out each function type in new folders if I wanted to

# NETWORK

private_ip() {
  ip route get 1 | head -1 | cut -d' ' -f7
}

public_ip() {
  curl -s https://ipinfo.io/ip
}
