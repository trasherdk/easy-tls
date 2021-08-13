#!/bin/sh

# Copyright - negotiable
copyright ()
{
: << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-client-disconnect.sh -- Do simple magic
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
	help_msg="
  easytls-client-disconnect.sh

  This script is intended to be used by tls-crypt-v2 client keys
  generated by EasyTLS.  See: https://github.com/TinCanTech/easy-tls

  Options:
  help|-h|--help         This help text.
  -v|--verbose           Be a lot more verbose at run time (Not Windows).

  -t|--tmp-dir=<DIR>     Temp directory where server-scripts write data.
                         Default: *nix /tmp/easytls
                                  Windows C:/Windows/Temp/easytls
  -b|--base-dir=<DIR>    Path to OpenVPN base directory. (Windows Only)
                         Default: C:/Progra~1/OpenVPN
  -o|--ovpnbin-dir=<DIR> Path to OpenVPN bin directory. (Windows Only)
                         Default: C:/Progra~1/OpenVPN/bin
  -e|--ersabin-dir=<DIR> Path to Easy-RSA3 bin directory. (Windows Only)
                         Default: C:/Progra~1/Openvpn/easy-rsa/bin

  Exit codes:
  0   - Allow connection, Client hwaddr is correct or not required.

  7   - Disallow connection, X509 certificate incorrect for this TLS-key.
  8   - Disallow connection, missing X509 client cert serial. (BUG)
  9   - Disallow connection, unexpected failure. (BUG)

  18  - BUG Disallow connection, failed to read c_ext_md_file
  19  - BUG Disallow connection, failed to parse metadata strig

  21  - USER ERROR Disallow connection, options error.

  60  - USER ERROR Disallow connection, missing Temp dir
  61  - USER ERROR Disallow connection, missing Base dir
  62  - USER ERROR Disallow connection, missing Easy-RSA bin dir
  63  - USER ERROR Disallow connection, missing Openvpn bin dir
  64  - USER ERROR Disallow connection, missing openssl.exe
  65  - USER ERROR Disallow connection, missing cat.exe
  66  - USER ERROR Disallow connection, missing date.exe
  67  - USER ERROR Disallow connection, missing grep.exe
  68  - USER ERROR Disallow connection, missing sed.exe
  69  - USER ERROR Disallow connection, missing printf.exe
  70  - USER ERROR Disallow connection, missing rm.exe

  253 - Disallow connection, exit code when --help is called.
  254 - BUG Disallow connection, fail_and_exit() exited with default error code.
  255 - BUG Disallow connection, die() exited with default error code.
"
	print "${help_msg}"

	# For secrity, --help must exit with an error
	exit 253
}

# Wrapper around 'printf' - clobber 'print' since it's not POSIX anyway
# shellcheck disable=SC1117
print () { "${EASYTLS_PRINTF}" "%s\n" "${1}"; }
verbose_print () { [ "${EASYTLS_VERBOSE}" ] && print "${1}"; return 0; }

# Exit on error
die ()
{
	delete_metadata_files
	verbose_print "<ERROR> ${status_msg}"
	[ -n "${help_note}" ] && print "${help_note}"
	print "ERROR: ${1}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
	exit "${2:-255}"
}

# failure not an error
fail_and_exit ()
{
	delete_metadata_files
	print "<FAIL> ${status_msg}"
	print "${failure_msg}"
	print "${1}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<FAIL> ${status_msg}" "${failure_msg}" "${1}" > "${EASYTLS_WLOG}"
	exit "${2:-254}"
} # => fail_and_exit ()

# Delete all metadata files
delete_metadata_files ()
{
	"${EASYTLS_RM}" -f \
		"${generic_metadata_file}" \
		"${generic_ext_md_file}" \
		"${client_metadata_file}" \
		"${client_ext_md_file}" \
		"${EASYTLS_KILL_FILE}" \

	update_status "temp-files deleted"
}

# Log fatal warnings
warn_die ()
{
	if [ -n "${1}" ]
	then
		fatal_msg="${fatal_msg}
${1}"
	else
		[ -z "${fatal_msg}" ] || die "${fatal_msg}" 21
	fi
}

# Update status message
update_status ()
{
	status_msg="${status_msg} => ${*}"
}

# Remove colons ':' and up-case
format_number ()
{
	"${EASYTLS_PRINTF}" '%s' "${1}" | \
		"${EASYTLS_SED}" -e 's/://g' -e 'y/abcdef/ABCDEF/'
}

# Allow connection
connection_allowed ()
{
	absolute_fail=0
	update_status "disconnection success"
}

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# Defaults
	EASYTLS_srv_pid=$PPID

	# Log message
	status_msg="* EasyTLS-client-disconnect"

	# Identify Windows
	EASYRSA_KSH='@(#)MIRBSD KSH R39-w32-beta14 $Date: 2013/06/28 21:28:57 $'
	[ "${KSH_VERSION}" = "${EASYRSA_KSH}" ] && EASYTLS_FOR_WINDOWS=1

	# Required binaries
	EASYTLS_OPENSSL='openssl'
	EASYTLS_AWK='awk'
	EASYTLS_CAT='cat'
	EASYTLS_DATE='date'
	EASYTLS_GREP='grep'
	EASYTLS_SED='sed'
	EASYTLS_PRINTF='printf'
	EASYTLS_RM='rm'

	# Directories and files
	if [ $EASYTLS_FOR_WINDOWS ]
	then
		# Windows
		host_drv="${PATH%%\:*}"
		base_dir="${EASYTLS_base_dir:-${host_drv}:/Progra~1/Openvpn}"
		EASYTLS_ersabin_dir="${EASYTLS_ersabin_dir:-${base_dir}/easy-rsa/bin}"
		EASYTLS_ovpnbin_dir="${EASYTLS_ovpnbin_dir:-${base_dir}/bin}"

		[ -d "${base_dir}" ] || exit 61
		[ -d "${EASYTLS_ersabin_dir}" ] || exit 62
		[ -d "${EASYTLS_ovpnbin_dir}" ] || exit 63
		[ -f "${EASYTLS_ovpnbin_dir}/${EASYTLS_OPENSSL}.exe" ] || exit 64
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_AWK}.exe" ] || exit 65
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_CAT}.exe" ] || exit 65
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_DATE}.exe" ] || exit 66
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_GREP}.exe" ] || exit 67
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_SED}.exe" ] || exit 68
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_PRINTF}.exe" ] || exit 69
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_RM}.exe" ] || exit 70

		export PATH="${EASYTLS_ersabin_dir};${EASYTLS_ovpnbin_dir};${PATH}"
	fi
} # => init ()

# Dependancies
deps ()
{
	if [ $EASYTLS_FOR_WINDOWS ]
	then
		WIN_TEMP="${host_drv}:/Windows/Temp"
		export EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-${WIN_TEMP}}"
	else
		export EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-/tmp}"
	fi

	# Test temp dir
	[ -d "${EASYTLS_tmp_dir}" ] || exit 60

	# Temp files name stub
	temp_stub="${EASYTLS_tmp_dir}/easytls-${EASYTLS_srv_pid}"

	# Windows log
	EASYTLS_WLOG="${temp_stub}-client-disconnect.log."

	# Conn track
	EASYTLS_CONN_TRAC="${temp_stub}-conn-trac"

	# Kill client file
	EASYTLS_KILL_FILE="${temp_stub}-kill-client"
}

# client metadata_string into variables
client_metadata_string_to_vars ()
{
	c_tlskey_serial="${1%%-*}"
	c_md_seed="${metadata_string#*-}"
	#md_padding="${md_seed%%--*}"
	c_md_easytls_ver="${1#*--}"
	c_md_easytls="${c_md_easytls_ver%-*.*}"

	c_md_identity="${2%%-*}"
	#md_srv_name="${2##*-}"

	c_md_serial="${3}"
	c_md_date="${4}"
	c_md_custom_g="${5}"
	c_md_name="${6}"
	c_md_subkey="${7}"
	c_md_opt="${8}"
	c_md_hwadds="${9}"
} # => metadata_string_to_vars ()

#######################################

# Initialise
init

# Options
while [ -n "${1}" ]
do
	# Separate option from value:
	opt="${1%%=*}"
	val="${1#*=}"
	empty_ok="" # Empty values are not allowed unless expected

	case "${opt}" in
	help|-h|--help)
		empty_ok=1
		help_text
	;;
	--vars)
		vars_file="${val}"
	;;
	-v|--verbose)
		empty_ok=1
		EASYTLS_VERBOSE=1
	;;
	-b|--base-dir)
		EASYTLS_base_dir="${val}"
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="${val}"
	;;
	-o|--openvpn-bin-dir)
		EASYTLS_ovpnbin_dir="${val}"
	;;
	-e|--easyrsa-bin-dir)
		EASYTLS_ersabin_dir="${val}"
	;;
	*)
		empty_ok=1
		if [ -f "${opt}" ]
		then
			# Do not need this in the log but keep it here for reference
			#[ $EASYTLS_VERBOSE ] && echo "Ignoring temp file: $opt"
			:
		else
			[ "${EASYTLS_VERBOSE}" ] && warn_die "Unknown option: ${opt}"
		fi
	;;
	esac

	# fatal error when no value was provided
	if [ ! $empty_ok ] && { [ "${val}" = "${1}" ] || [ -z "${val}" ]; }; then
		warn_die "Missing value to option: ${opt}"
	fi
	shift
done

# Dependencies
deps

# Report and die on fatal warnings
warn_die

# Source vars file
if [ -f "${vars_file}" ]
then
	. "${vars_file}" || die "source failed: ${vars_file}"
	update_status "vars loaded"
else
	update_status "No vars loaded"
fi

# Write env file
[ $WRITE_ENV ] && {
	env_file="${temp_stub}-client-connect.env"
	if [ $EASYTLS_FOR_WINDOWS ]; then
		set > "${env_file}"
	else
		env > "${env_file}"
	fi
	unset env_file
	}

# Source conn-trac lib
[ $ENABLE_CONN_TRAC ] && {
	prog_dir="${0%/*}"
	lib_file="${prog_dir}/easytls-conn-trac.lib"
	[ -f "${lib_file}" ] || die "Missing ${lib_file}"
	. "${lib_file}"
	unset lib_file
	}

# Update log message
update_status "CN:${X509_0_CN}"

# Set Client certificate serial number from Openvpn env
# shellcheck disable=SC2154
client_serial="$(format_number "${tls_serial_hex_0}")"

# Verify Client certificate serial number
[ -z "${client_serial}" ] && {
	help_note="Openvpn failed to pass a client serial number"
	die "NO CLIENT SERIAL" 8
	}

# easytls client metadata file
generic_metadata_file="${temp_stub}-gmd"
client_metadata_file="${temp_stub}-cmd-${client_serial}"

# --tls-verify output to --client-connect
# shellcheck disable=SC2154
generic_ext_md_file="${generic_metadata_file}-${untrusted_ip}-${untrusted_port}"
client_ext_md_file="${client_metadata_file}-${untrusted_ip}-${untrusted_port}"

# Verify client_ext_md_file
if [ -f "${client_ext_md_file}" ]
then
	# Client cert serial matches
	update_status "X509 serial matched"
	# Get client metadata_string
	metadata_string="$("${EASYTLS_CAT}" "${client_ext_md_file}")"
	[ -n "${metadata_string}" ] || \
		fail_and_exit "failed to read client_ext_md_file" 18
	# Populate client metadata variables
	client_metadata_string_to_vars $metadata_string
	[ -n "${c_tlskey_serial}" ] || \
		fail_and_exit "failed to set c_tlskey_serial" 19
	unset metadata_string
	update_status "client_ext_md_file loaded"
else
	# cert serial does not match - ALWAYS fail
	die "CLIENT X509 SERIAL MISMATCH" 7
fi

# Any failure_msg means fail_and_exit
[ -n "${failure_msg}" ] && fail_and_exit "NEIN: ${failure_msg}" 9

# For DUBUG
[ "${FORCE_ABSOLUTE_FAIL}" ] && \
	absolute_fail=1 && failure_msg="FORCE_ABSOLUTE_FAIL"

# disconnect can not fail ..
connection_allowed

# There is only one way out of this...
if [ $absolute_fail -eq 0 ]
then
	# Update connection tracking
	conn_trac_record="${c_tlskey_serial:-${g_tlskey_serial}}"
	conn_trac_record="${conn_trac_record}=${c_md_serial:-${g_md_serial}}"
	conn_trac_record="${conn_trac_record}=${untrusted_ip}"
	conn_trac_record="${conn_trac_record}=${untrusted_port}"
	conn_trac_disconnect "${conn_trac_record}"

	# Delete files which are no longer needed
	delete_metadata_files

	# All is well
	verbose_print "<EXOK> ${status_msg}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n" \
		"${status_msg}" > "${EASYTLS_WLOG}"
	exit 0
fi

# Otherwise
fail_and_exit "ABSOLUTE FAIL" 9
