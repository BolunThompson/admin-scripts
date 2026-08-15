#!/usr/bin/env bash

# could make cross platform if I needed to
# sigh, include guards. This feels like C.

if [[ -n $SCRIPTS_LIB_INCLUDED ]]; then
	return 0
fi

readonly SCRIPTS_LIB_INCLUDED=yes

trap 'echo; exit' INT

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

as_root() {
	if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
		"$@"
	else
		sudo -i "$@"
	fi
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

rebuild() {
	local flake_path="${1:-$HOME/dotfiles}"

	if command -v nixos-rebuild >/dev/null 2>&1; then
		as_root nixos-rebuild switch --flake "$flake_path"
	elif command -v darwin-rebuild >/dev/null 2>&1; then
		as_root scutil --set LocalHostName "UCLAMac"
		as_root darwin-rebuild switch --flake "$flake_path"
	elif command -v home-manager >/dev/null 2>&1; then
		home-manager switch --flake "$flake_path" -b backup
	else
		error "No rebuild command available!"
		exit 1
	fi
}

# factored out in case I switch password managers
passphrase() {
	bw get password SSH
}

update_dot() {
	assert_argc 1 "$@"
	cd "$HOME/dotfiles" || return
	local MSG="$1"
	shift
	if [[ $# -gt 0 ]]; then
		nixpkgs-fmt "$@" >/dev/null 2>&1
		git add "$@"
	else
		nixpkgs-fmt ./*.nix >/dev/null 2>&1
		git add --all
	fi
	git commit -m "$MSG" || true
	git push
	rebuild
}

update_scripts() {
	if [[ -v 1 ]]; then
		cd ~/admin-scripts || return
		git add --all
		git commit -m "$1" || true
	fi
	git push
	cd "$HOME/dotfiles" || return
	nix flake update
	git add flake.lock
	git commit -m "Update flake.lock"
	git push
	rebuild
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
as_owner() {
    local f="$1"; shift
    local u g
    u="$(stat -c %u -- "$f")"
    g="$(stat -c %g -- "$f")"
    if [ "$u" = "$(id -u)" ]; then
        "$@"
    else
        sudo -u "#$u" -g "#$g" env PATH="$PATH" -- "$@"
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
	"rebuild"
)
export PLIB_FUNCS
