#!/usr/bin/env bash

# could make cross platform if I needed to
# sigh, include guards. This feels like C.

if [[ -n ${SCRIPTS_LIB_INCLUDED:-} ]]; then
	return 0
fi

readonly SCRIPTS_LIB_INCLUDED=yes
readonly CONFIG=/etc/nixos/
export CONFIG

set -euo pipefail

if [[ -t 1 ]]; then
	ERR_C='\e[0;31m'
	WRN_C='\e[0;33m'
	SUC_C='\e[0;32m'
	RESET='\e[0m'
fi

# else unset

# LOGGING

error() {
	printf "${ERR_C:-}ERROR: %s${RESET:-}\n" "$1"
}

warn() {
	printf "${WRN_C:-}WARN: %s${RESET:-}\n" "$1"
}

success() {
	printf "${SUC_C:-}SUCCESS: %s${RESET:-}\n" "$1"
}

note() {
	printf "NOTE: %s\n" "$1"
}

# MISC

ensure_root() {
	if [[ -z $1 ]]; then
		read -r -s -p "Password for $USER: " password
		echo >&2
	else
		local -r password="$1"
	fi

	# echo isn't safe because on different bash shells it can have different
	# outputs in regards to escapes

	# echo and printf are safe in regards to not showing up in ps
	# because they are shell builtins

	# herestrings aren't used because they're less posix compliant (and more confusing)
	printf "%s" "$password" | tee >(sudo -p "" -Sv)
}

assert_argc() {
	local argc="$1"
	shift
	if [[  $argc != "$#" ]]; then
		error "$argc args expected but $# passed!"
		exit
	fi
}

# NETWORK

private_ip() {
	ip route get 1 | head -1 | cut -d' ' -f7
}

public_ip() {
	curl -s https://ipinfo.io/ip -w "\n"
}

# factored out in case I switch password managers
passphrase() {
	bw get password SSH
}

update_dot() {
	assert_argc 1 "$@"
	cd "$CONFIG" || return
	sudo git add --all
	sudo git commit -m "$1"
	git push
	sudo nixpkgs-fmt ./*.nix  > /dev/null 2>&1
	sudo nixos-rebuild switch
}

ssh_poweroff() {
	if [[ -n $SSH_CLIENT ]]; then
		echo "Do you really want to do that?"
	else
		poweroff
	fi
}

readonly PLIB_FUNCS=(
	"private_ip"
	"public_ip"
	"ssh_pass"
	"update_dot"
	"ssh_poweroff"
	"passphrase"
)
export PLIB_FUNCS
