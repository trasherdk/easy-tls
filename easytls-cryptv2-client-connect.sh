#!/bin/sh

# Copyright - negotiable
copyright ()
{
: << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-cryptv2-client-connect.sh -- Do simple magic
#
# Copyright (C) 2020 Richard Bonhomme (Friday 13th of March 2020)
# https://github.com/TinCanTech/easy-tls
# tincantech@protonmail.com
# All Rights reserved.
#
# This code is released under version 2 of the GNU GPL
# See LICENSE of this project for full licensing details.
#
# Acknowledgement:
# syzzer: https://github.com/OpenVPN/openvpn/blob/master/doc/tls-crypt-v2.txt
#
# Lock client connections to specific client devices.
#
VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
}

# Help
help_text ()
{
	help_msg='
  easytls-cryptv2-client-connect.sh

  This script is intended to be used by tls-crypt-v2 client keys
  generated by EasyTLS.  See: https://github.com/TinCanTech/easy-tls

  Options:
  help|-h|--help      This help text.
  -v|--verbose        Be a lot more verbose at run time (Not Windows).
  -a|--allow-no-check If the key has a hardware-address configured
                      and the client did NOT use --push-peer-info
                      then allow the connection.  Otherwise, keys with a
                      hardware-address MUST use --push-peer-info.
  -p|--push-required  Require all clients to use --push-peer-info.
  -k|--key-required   Require all client keys to have a hardware-address.
  -t|--tmp-dir        Temp directory where the hardware address list is written.
                      (Required only if easytls-cryptv2-client-connect.sh is used)
                      Default: *nix /tmp | Windows C:/Windows/Temp
  -o|--ovpnbin-dir    Path to OpenVPN bin directory. (Windows Only)
                      Default: C:/Progra~1/OpenVPN/bin
  -e|--ersabin-dir    Path to Easy-RSA3 bin directory. (Windows Only)
                      Default: C:/Progra~1/Openvpn/easy-rsa/bin

  Exit codes:
  0   - Allow connection, Client hwaddr is correct or not required.
  1   - Disallow connection, pushed hwaddr does not match.
  2   - Disallow connection, hwaddr required and not pushed.
  3   - Disallow connection, hwaddr required and not keyed.
  4   - Disallow connection, X509 certificate incorrect for this TLS-key.
  5   - Disallow connection, hwaddr verification has not been configured.
  6   - Disallow connection, missing Required binaries.
  8   - Disallow connection, missing X509 client cert serial. (BUG)
  9   - Disallow connection, unexpected failure. (BUG)
  21  - USER ERROR Disallow connection, options error.

  253 - Disallow connection, exit code when --help is called.
  254 - BUG Disallow connection, fail_and_exit() exited with default error code.
  255 - BUG Disallow connection, die() exited with default error code.
'
	"$EASYTLS_PRINTF" "%s\n" "$help_msg"

	# For secrity, --help must exit with an error
	exit 253
}

# Wrapper around 'printf' - clobber 'print' since it's not POSIX anyway
# shellcheck disable=SC1117
print() { "$EASYTLS_PRINTF" "%s\n" "$1"; }

# Exit on error
die ()
{
	"$EASYTLS_RM" -f "$client_metadata_file"
	[ -n "$help_note" ] && "$EASYTLS_PRINTF" "\n%s\n" "$help_note"
	"$EASYTLS_PRINTF" "\n%s\n" "ERROR: $1"
	"$EASYTLS_PRINTF" "%s\n" "https://github.com/TinCanTech/easy-tls"
	exit "${2:-255}"
}

# easytls-cryptv2-client-connect failure, not an error.
fail_and_exit ()
{
	"$EASYTLS_RM" -f "$client_metadata_file"
	if [ $EASYTLS_VERBOSE ]
	then
		"$EASYTLS_PRINTF" "%s " "$easytls_msg"
		[ -z "$success_msg" ] || "$EASYTLS_PRINTF" "%s\n" "$success_msg"
		"$EASYTLS_PRINTF" "%s\n%s\n" "$failure_msg $common_name" "$1"

		"$EASYTLS_PRINTF" "%s\n" "https://github.com/TinCanTech/easy-tls"
	else
		"$EASYTLS_PRINTF" "%s %s %s %s\n" "$easytls_msg" "$success_msg" "$failure_msg" "$1"
	fi
	exit "${2:-254}"
} # => fail_and_exit ()

# Log fatal warnings
warn_die ()
{
	if [ -n "$1" ]
	then
		fatal_msg="${fatal_msg}
$1"
	else
		[ -z "$fatal_msg" ] || die "$fatal_msg" 21
	fi
}

# Log warnings
warn_log ()
{
	if [ -n "$1" ]
	then
		warn_msg="${warn_msg}
$1"
	else
		[ -z "$warn_msg" ] || "$EASYTLS_PRINTF" "%s\n" "$warn_msg"
	fi
}

# Get the client certificate serial number from env
get_ovpn_client_serial ()
{
	"$EASYTLS_PRINTF" '%s' "$tls_serial_hex_0" | \
		"$EASYTLS_SED" -e 's/://g' -e 'y/abcdef/ABCDEF/'
}

# Get the client hardware address from env
get_ovpn_client_hwaddr ()
{
	"$EASYTLS_PRINTF" '%s' "$IV_HWADDR" | \
		"$EASYTLS_SED" -e 's/://g' -e 'y/abcdef/ABCDEF/'
}

# Allow connection
connection_allowed ()
{
	"$EASYTLS_RM" -f "$client_metadata_file"
	absolute_fail=0
}

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# Defaults
	EASYTLS_server_pid=$PPID

	# Log message
	easytls_msg="* EasyTLS-cryptv2-client-connect"
}

# Dependancies
deps ()
{
	# Required binaries
	EASYTLS_OPENSSL="openssl"
	EASYTLS_CAT="cat"
	EASYTLS_DATE="date"
	EASYTLS_GREP="grep"
	EASYTLS_SED="sed"
	EASYTLS_PRINTF="printf"
	EASYTLS_RM='rm'

	# Directories and files
	if [ "$KSH_VERSION" ]
	then
		# Windows
		EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-C:/Windows/Temp}"
		def_bin_dir="C:/Progra~1/Openvpn"
		EASYTLS_ersabin_dir="${EASYTLS_ersabin_dir:-${def_bin_dir}/easy-rsa/bin}"
		EASYTLS_ovpnbin_dir="${EASYTLS_ovpnbin_dir:-${def_bin_dir}/bin}"
		export PATH="${EASYTLS_ersabin_dir};${EASYTLS_ovpnbin_dir};${PATH};"
		help_note="Easy-TLS requires binary files provided by Easy-RSA"
		[ -d "$EASYTLS_ersabin_dir" ] || die "Missing easy-rsa\bin dir" 35
		[ -d "$EASYTLS_ovpnbin_dir" ] || die "Missing Openvpn\bin dir" 36
		[ -f "${EASYTLS_ovpnbin_dir}/${EASYTLS_OPENSSL}.exe" ] \
			|| die "Missing openssl" 119
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_CAT}.exe" ] || \
			die "Missing cat" 113
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_DATE}.exe" ] || \
			die "Missing date" 114
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_GREP}.exe" ] || \
			die "Missing grep" 115
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_SED}.exe" ] || \
			die "Missing sed" 116
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_PRINTF}.exe" ] || \
			die "Missing printf" 118
		unset help_note
	else
		EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-/tmp}"
	fi

	# Set Client certificate serial number from Openvpn env
	client_serial="$(get_ovpn_client_serial)"

	# Verify Client certificate serial number
	[ -n "$client_serial" ] || die "NO CLIENT SERIAL" 8

	# Set client_metadata_file
	client_metadata_file="$EASYTLS_tmp_dir/$client_serial.$EASYTLS_server_pid"

	# Verify client_metadata_file
	if [ -f "$client_metadata_file" ]
	then
		# Client cert serial matches
		easytls_msg="${easytls_msg} ==> X509 serial matched"
	else
		# cert serial does not match - ALWAYS fail
		fail_and_exit "CLIENT X509 SERIAL MISMATCH" 4
	fi
}

#######################################

# Initialise
init

# Options
while [ -n "$1" ]
do
	# Separate option from value:
	opt="${1%%=*}"
	val="${1#*=}"
	empty_ok="" # Empty values are not allowed unless expected

	case "$opt" in
	help|-h|-help|--help)
		empty_ok=1
		help_text
	;;
	-v|--verbose)
		empty_ok=1
		EASYTLS_VERBOSE=1
	;;
	-a|--allow-no-check)
		empty_ok=1
		allow_no_check=1
	;;
	-p|--push-hwaddr-required)
		empty_ok=1
		push_hwaddr_required=1
	;;
	-k|--key-hwaddr-required)
		empty_ok=1
		key_hwaddr_required=1
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="$val"
	;;
	-o|--openvpn-bin-dir)
		EASYTLS_ovpnbin_dir="$val"
	;;
	-e|--easyrsa-bin-dir)
		EASYTLS_ersabin_dir="$val"
	;;
	*)
		empty_ok=1
		if [ -f "$opt" ]
		then
			[ $EASYTLS_VERBOSE ] && warn_log "Ignoring temp file: $opt"
		else
			[ $EASYTLS_VERBOSE ] && warn_log "Ignoring unknown option: $opt"
		fi
	;;
	esac

	# fatal error when no value was provided
	if [ ! $empty_ok ] && { [ "$val" = "$1" ] || [ -z "$val" ]; }; then
		warn_die "Missing value to option: $opt"
	fi
	shift
done

# Dependencies
deps

# Report and die on fatal warnings
warn_die

# Report option warnings
warn_log

# Set only for NO keyed hwaddr
if "$EASYTLS_GREP" -q '000000000000' "$client_metadata_file"
then
	key_hwaddr_missing=1
fi

# If keyed hwaddr is required and missing then fail - No exceptions
[ $key_hwaddr_required ] && [ $key_hwaddr_missing ] && \
	fail_and_exit "KEYED HWADDR REQUIRED BUT NOT KEYED" 3


# Set hwaddr from Openvpn env
# This is not a dep. different clients may not push-peer-info
push_hwaddr="$(get_ovpn_client_hwaddr)"
[ -z "$push_hwaddr" ] && push_hwaddr_missing=1

# If pushed hwaddr is required and missing then fail - No exceptions
[ $push_hwaddr_required ] && [ $push_hwaddr_missing ] && \
	fail_and_exit "PUSHED HWADDR REQUIRED BUT NOT PUSHED" 2


# Verify hwaddr
if [ $key_hwaddr_missing ]
then
	# No keyed hwaddr
	success_msg="==> Key is not locked to hwaddr"
	connection_allowed
else
	# key has a hwaddr
	if [ $push_hwaddr_missing ]
	then
		# push_hwaddr_missing and allow_no_check
		if [ $allow_no_check ]
		then
			success_msg="==> hwaddr not pushed and not required"
			connection_allowed
		else
			# push_hwaddr_missing NOT allow_no_check
			fail_and_exit "PUSHED HWADDR REQUIRED BUT NOT PUSHED" 2
		fi
	else
		# hwaddr is pushed
		if "$EASYTLS_GREP" -q "$push_hwaddr" "$client_metadata_file"
		then
			# MATCH!
			success_msg="==> hwaddr $push_hwaddr pushed and matched!"
			connection_allowed
		else
			"$EASYTLS_GREP" --version > /dev/null || die 'Missing file: grep'
			# push does not match key hwaddr
			fail_and_exit "HWADDR MISMATCH" 1
		fi
	fi
fi

# Any failure_msg means fail_and_exit
[ -n "$failure_msg" ] && fail_and_exit "NEIN: $failure_msg" 9

# For DUBUG
[ "$FORCE_ABSOLUTE_FAIL" ] && absolute_fail=1 && \
	failure_msg="FORCE_ABSOLUTE_FAIL"

# There is only one way out of this...
[ $absolute_fail -eq 0 ] || fail_and_exit "ABSOLUTE FAIL" 9

# All is well
[ $EASYTLS_VERBOSE ] && \
	"$EASYTLS_PRINTF" "%s\n" "<EXOK> $easytls_msg $success_msg"

exit 0
