#!/usr/bin/env bash

# could make cross platform if I needed to
# sigh, include guards. This feels like C.

if [[ -n $SCRIPTS_LIB_INCLUDED ]]; then
	return 0
fi

readonly SCRIPTS_LIB_INCLUDED=yes
readonly CONFIG=/etc/nixos/
export CONFIG

if [[ -t 1 ]]; then
	ERR_C='\e[0;31m'
	WRN_C='\e[0;33m'
	SUC_C='\e[0;32m'
	RESET='\e[0m'
fi

# else unset

# LOGGING

error() {
	printf "${ERR_C}ERROR: %s$RESET\n" "$1"
}

warn() {
	printf "${WRN_C}WARN: %s$RESET\n" "$1"
}

success() {
	printf "${SUC_C}SUCCESS: %s$RESET\n" "$1"
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
	if [[ $argc -gt $# ]]; then
		error "$argc args expected but $# passed!"
		exit 1
	fi
}

# NETWORK

private_ip() {
	ip route get 1 | head -1 | cut -d' ' -f7
}

public_ip() {
	curl -s https://ipinfo.io/ip -w "\n"
}

is_online() {
	assert_argc 1 "$@"
	if ! [[ -v 2 ]]; then
		# attempts to detect the existence of a subdirectory
		if [[ $1 =~ / ]]; then
			curl -o /dev/null --head --silent --fail "$1"
		else
			ping -q -c2 "$1" &>/dev/null
		fi
	else
		local ncr
		ncr="$(nc -v -w 2 -z "$1" "$2" 2>&1)"

		case "$ncr" in
		*timed\ out)
			return 124
			;;
		*refused)
			return 111
			;;
		*open)
			return 0
			;;
		*)
			error "Unknown response: $ncr"
			return
			;;
		esac
	fi
} >&2

# factored out in case I switch password managers
passphrase() {
	bw get password SSH
}

update_dot() {
	assert_argc 1 "$@"
	cd "$CONFIG" || return
	local MSG="$1"
	shift
	if [[ $# -gt 0 ]]; then
		sudo nixpkgs-fmt "$@" >/dev/null 2>&1
		sudo git add "$@"
	else
		sudo nixpkgs-fmt ./*.nix >/dev/null 2>&1
		sudo git add --all
	fi
	sudo git commit -m "$MSG" || true
	sudo git push
	sudo nixos-rebuild switch
}

update_scripts() {
	if [[ -v 1 ]]; then
		cd ~/scripts || return
		git add --all
		git commit -m "$1" || true
		git push
	fi
	cd "$CONFIG" || return
	sudo nix flake update
	sudo git add flake.lock
	sudo git commit -m "Update flake.lock"
	sudo git push
	sudo nixos-rebuild switch
}

update_templates() {
	assert_argc 1 "$@"
	cd ~/templates || return
	git add --all
	git commit -m "$1" || true
	git push
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
	"update_dot"
	"update_scripts"
	"update_templates"
	"ssh_poweroff"
	"passphrase"
	"is_online"
)
export PLIB_FUNCS
