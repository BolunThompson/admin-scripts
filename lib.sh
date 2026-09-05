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
	echo "WARNING: Update your system local configuration md to include any new items!"

	if command -v nixos-rebuild >/dev/null 2>&1; then
		as_root nixos-rebuild switch --flake "$flake_path"
	elif command -v darwin-rebuild >/dev/null 2>&1; then
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


# Overridable from the environment if the model lineup changes.
: "${ASK_MODEL:=gpt-5.6-luna}"
: "${ASK_REASONING_EFFORT:=low}"

# Quick one-shot programming question, answered by codex non-interactively.
# Low reasoning effort on purpose: this is for things you'd otherwise google,
# not for anything that needs to read the repo or change files.
ask() {
	if ! [[ -v 1 ]]; then
		error "usage: ask <question>"
		return 1
	fi
	if ! command -v codex >/dev/null 2>&1; then
		error "codex is not on PATH"
		return 1
	fi

	local prompt
	prompt=$(
		cat <<-EOF
			You are answering a quick programming question from an experienced
			developer at their terminal. Answer directly and concisely.

			Rules:
			- Lead with the answer. No preamble, no restating the question.
			- Code snippets only where they are the clearest answer. No boilerplate.
			- If the answer is a command or one-liner, just give it.
			- Assume competence: skip basics, caveats, and safety warnings.
			- If the question is genuinely ambiguous, state the most likely
			  reading and answer that rather than asking to clarify.
			- Keep it under ~10 lines unless the question truly needs more.

			Question: $*
		EOF
	)

	codex exec \
		--model "$ASK_MODEL" \
		--config "model_reasoning_effort=\"$ASK_REASONING_EFFORT\"" \
		--sandbox read-only \
		--skip-git-repo-check \
		-- "$prompt"
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
	"ask"
)
export PLIB_FUNCS
