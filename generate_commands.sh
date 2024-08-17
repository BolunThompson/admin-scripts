#!/usr/bin/env bash

. public_lib.sh

for name in $(compgen -A function); do
	cat >"$name" <<-EOF
	. public_lib.sh
	$name "\$@"
	EOF
done
