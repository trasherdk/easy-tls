#!/bin/sh

EASYTLS_VERSION="2.7.0"

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
  -V|--version
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
  71  - USER ERROR Disallow connection, missing metadata.lib

  77  - BUG Disallow connection, failed to sources vars file
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

verbose_print ()
{
	[ "${EASYTLS_VERBOSE}" ] || return 0
	print "${1}"
	print ""
}

# Set the Easy-TLS version
easytls_version ()
{
	verbose_print
	print "Easy-TLS version: ${EASYTLS_VERSION}"
	verbose_print
} # => easytls_version ()

# Exit on error
die ()
{
	# TLSKEY connect log
	tlskey_status "FATAL" || update_status "tlskey_status FATAL"

	easytls_version
	verbose_print "<ERROR> ${status_msg}"
	[ -z "${help_note}" ] || print "${help_note}"
	[ -z "${failure_msg}" ] || print "${failure_msg}"
	print "ERROR: ${1}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
	#exit "${2:-255}"
	echo 'XXXXX CD - Kill Server XXXXX'
	echo 1 > "${temp_stub}-die"
	if [ $ENABLE_KILL_PPID ]; then
		if [ $EASYTLS_FOR_WINDOWS ]; then
			"${EASYTLS_PRINTF}" "%s\n%s\n" \
				"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
			[ $DISABLE_KILL_PPID ] || taskkill /F /PID ${EASYTLS_srv_pid}
		else
			[ $DISABLE_KILL_PPID ] || kill -15 ${EASYTLS_srv_pid}
		fi
	fi
	exit "${2:-255}"
} # => die ()

# failure not an error
fail_and_exit ()
{
	delete_metadata_files
	print "<FAIL> ${status_msg}"
	print "${failure_msg}"
	print "${1}"

	# TLSKEY connect log
	tlskey_status "!*! FAIL" || update_status "tlskey_status FAIL"

	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<FAIL> ${status_msg}" "${failure_msg}" "${1}" > "${EASYTLS_WLOG}"
	exit "${2:-254}"
} # => fail_and_exit ()

# Delete all metadata files - Currently UNUSED
delete_metadata_files ()
{
	"${EASYTLS_RM}" -f "${EASYTLS_KILL_FILE}"
	update_status "temp-files deleted"
} # => delete_metadata_files ()

# Log fatal warnings
warn_die ()
{
	if [ -n "${1}" ]; then
		fatal_msg="${fatal_msg}
${1}"
	else
		[ -z "${fatal_msg}" ] || die "${fatal_msg}" 21
	fi
} # => warn_die ()

# Update status message
update_status ()
{
	status_msg="${status_msg} => ${*}"
} # => update_status ()

# Remove colons ':' and up-case
format_number ()
{
	"${EASYTLS_PRINTF}" '%s' "${1}" | \
		"${EASYTLS_SED}" -e 's/://g' -e 'y/abcdef/ABCDEF/'
} # => format_number ()

# Allow disconnection
disconnect_accepted ()
{
	absolute_fail=0
	update_status "disconnect completed"
} # => disconnect_accepted ()

# Update conntrac
update_conntrac ()
{
	# Source conn-trac lib
	prog_dir="${0%/*}"
	lib_file="${prog_dir}/easytls-conntrac.lib"
	[ -f "${lib_file}" ] || {
		easytls_url="https://github.com/TinCanTech/easy-tls"
		easytls_wiki="/wiki/download-and-install"
		#easytls_rawurl="https://raw.githubusercontent.com/TinCanTech/easy-tls"
		#easytls_file="/master/easytls-conntrac.lib"
		help_note="See: ${easytls_url}${easytls_wiki}"
		die "Missing ${lib_file}" 159
		}
	# shellcheck source=./easytls-conntrac.lib
	. "${lib_file}"
	unset -v lib_file

	# Update connection tracking
	conntrac_record="${UV_TLSKEY_SERIAL:-TLSAC}"
	conntrac_record="${conntrac_record}=${client_serial}"
	# If common_name is not set then this is bug 160-2
	# Use username, which is still set, when common_name is lost
	# Set the username alternative first
	# shellcheck disable=SC2154
	conntrac_alt_rec="${conntrac_record}==${username}"
	conntrac_alt2_rec="${conntrac_record}==${X509_0_CN}"
	# shellcheck disable=SC2154
	conntrac_record="${conntrac_record}==${common_name}"

	# shellcheck disable=SC2154
	if [ -z "${ifconfig_pool_remote_ip}" ]; then
		[ $FATAL_CON_TRAC ] && fail_and_exit "IP_POOL_EXHASTED" 101
		ip_pool_exhausted=1
		conntrac_record="${conntrac_record}==0.0.0.0"
		conntrac_alt_rec="${conntrac_alt_rec}==0.0.0.0"
		conntrac_alt2_rec="${conntrac_alt2_rec}==0.0.0.0"
	else
		conntrac_record="${conntrac_record}==${ifconfig_pool_remote_ip}"
		conntrac_alt_rec="${conntrac_alt_rec}==${ifconfig_pool_remote_ip}"
		conntrac_alt2_rec="${conntrac_alt2_rec}==${ifconfig_pool_remote_ip}"
	fi

	# shellcheck disable=SC2154
	if [ -n "${peer_id}" ]; then
		conntrac_record="${conntrac_record}==${peer_id}"
		conntrac_alt_rec="${conntrac_alt_rec}==${peer_id}"
		conntrac_alt2_rec="${conntrac_alt2_rec}==${peer_id}"
	fi

	# shellcheck disable=SC2154
	conntrac_record="${conntrac_record}++${untrusted_ip}:${untrusted_port}"
	conntrac_alt_rec="${conntrac_alt_rec}++${untrusted_ip}:${untrusted_port}"
	conntrac_alt2_rec="${conntrac_alt2_rec}++${untrusted_ip}:${untrusted_port}"

	# Disconnect common_name
	conn_trac_disconnect "${conntrac_record}" "${EASYTLS_CONN_TRAC}" || {
		case $? in
		3)	# Missing conntrac file - Can happen if IP Pool exhausted
			[ $ip_pool_exhausted ] || {
				ENABLE_KILL_PPID=1
				die "CONNTRAC_DISCONNECT_FILE_MISSING" 97
				}
			# Ignore this error because it is expected
			update_status "IGNORE missing ct file due to IP POOL EXHAUSTED"
		;;
		2)	# Not fatal because errors are expected #160
			update_status "conn_trac_disconnect FAIL"
			conntrac_fail=1
			log_env=1
		;;
		1)	# Fatal because these are usage errors
			[ $FATAL_CONN_TRAC ] && {
				ENABLE_KILL_PPID=1
				die "CONNTRAC_DISCONNECT_FILE_ERROR" 99
				}
			update_status "conn_trac_disconnect ERROR"
			conntrac_error=1
			log_env=1
		;;
		9)	# Absolutely fatal
			ENABLE_KILL_PPID=1
			die "CONNTRAC_DISCONNECT_CT_LOCK_9.1" 96
		;;
		*)	# Absolutely fatal
			ENABLE_KILL_PPID=1
			die "CONNTRAC_DISCONNECT_UNKNOWN" 98
		;;
		esac
		}

	# If the first failed for number two then try again ..
	if [ $conntrac_fail ]; then
		# Disconnect username
		conn_trac_disconnect "${conntrac_alt_rec}" "${EASYTLS_CONN_TRAC}" || {
			case $? in
			2)	# fatal later - because errors could happen #160
				update_status "conn_trac_disconnect A-FAIL"
				conntrac_alt_fail=1
				log_env=1
			;;
			1)	# Fatal because these are usage errors
				[ $FATAL_CONN_TRAC ] && {
					ENABLE_KILL_PPID=1
					die "CONNTRAC_DISCONNECT_ALT_FILE_ERROR" 99
					}
				update_status "conn_trac_disconnect A-ERROR"
				conntrac_alt_error=1
				log_env=1
			;;
			9)	# Absolutely fatal
				ENABLE_KILL_PPID=1
				die "CONNTRAC_DISCONNECT_CT_LOCK_9.2" 96
			;;
			*)	# Absolutely fatal
				ENABLE_KILL_PPID=1
				die "CONNTRAC_DISCONNECT_UNKNOWN" 98
			;;
			esac
			}
	fi

	# Log failure
	if [ $conntrac_fail ] || [ $conntrac_error ]; then
		{
			[ -f "${EASYTLS_CONN_TRAC}.fail" ] && \
				"${EASYTLS_CAT}" "${EASYTLS_CONN_TRAC}.fail"
			"${EASYTLS_PRINTF}" '%s '  "${local_date_ascii}"
			[ $conntrac_fail ] && "${EASYTLS_PRINTF}" '%s ' "NFound"
			[ $conntrac_error ] && "${EASYTLS_PRINTF}" '%s ' "ERROR"
			[ $ip_pool_exhausted ] && "${EASYTLS_PRINTF}" '%s ' "IP-POOL"
			"${EASYTLS_PRINTF}" '%s\n' "DIS: ${conntrac_record}"
		} > "${EASYTLS_CONN_TRAC}.fail.tmp" || die "disconnect: conntrac file" 156
		"${EASYTLS_MV}" "${EASYTLS_CONN_TRAC}.fail.tmp" \
			"${EASYTLS_CONN_TRAC}.fail" || die "disconnect: conntrac file" 157
	fi

	if [ $conntrac_alt_fail ] || [ $conntrac_alt_error ]; then
		{
			[ -f "${EASYTLS_CONN_TRAC}.fail" ] && \
				"${EASYTLS_CAT}" "${EASYTLS_CONN_TRAC}.fail"
			"${EASYTLS_PRINTF}" '%s '  "${local_date_ascii}"
			[ $conntrac_alt_fail ] && "${EASYTLS_PRINTF}" '%s ' "A-NFound"
			[ $conntrac_alt_error ] && "${EASYTLS_PRINTF}" '%	s ' "A-ERROR"
			[ $ip_pool_exhausted ] && "${EASYTLS_PRINTF}" '%s ' "IP-POOL"
			"${EASYTLS_PRINTF}" '%s\n' "DIS: ${conntrac_alt_rec}"
		} > "${EASYTLS_CONN_TRAC}.fail.tmp" || die "disconnect: conntrac file" 158
		"${EASYTLS_MV}" "${EASYTLS_CONN_TRAC}.fail.tmp" \
			"${EASYTLS_CONN_TRAC}.fail" || die "disconnect: conntrac file" 159
	fi

	# Capture env
	if [ $log_env ]; then
		env_file="${temp_stub}-client-disconnect.env"
		if [ $EASYTLS_FOR_WINDOWS ]; then
			set > "${env_file}" || die "disconnect: env" 167
		else
			env > "${env_file}" || die "disconnect: env" 168
		fi
		unset -v env_file
	fi

	# This error is currently absolutely fatal
	# If IP pool exhausted then ignore conntrac_alt_fail
	[ ! $ip_pool_exhausted ] && [ $conntrac_alt_fail ] && {
		ENABLE_KILL_PPID=1
		die "disconnect: conntrac_alt_fail" 169
		}

	# OpenVPN Bug #160
	if [ $conntrac_fail ]; then
		if [ $ip_pool_exhausted ]; then
			# Ignored
			update_status "IP_POOL_EXHAUSTED IGNORED"
		else
			# Recovered from fail - Add your plugin
			:
			#update_status "disconnect: recovered"
		fi
	else
		# conntrac worked - Add your plugin
		:
		#update_status "disconnect: succeeded"
	fi
	unset -v \
		conntrac_fail conntrac_alt_fail \
		conntrac_error conntrac_alt_error \
		ip_pool_exhausted log_env
} # => update_conntrac ()

# Stack down
stack_down ()
{
	[ $stack_completed ] && die "STACK_DOWN CAN ONLY RUN ONCE" 161
	stack_completed=1

	[ $ENABLE_STACK ] || return 0

	# Only required if this file exists
	[ -f "${fixed_md_file}" ] || return 0

	# Lock
	acquire_lock "${easytls_lock_stub}-stack.d" || \
		die "acquire_lock:stack FAIL" 99
	update_status "stack-lock-acquired"

	unset -v stack_err
	i=0
	s=''

	while : ; do
		i=$(( i + 1 ))
		if [ -f "${fixed_md_file}_${i}" ]; then
			[ ${i} -eq 1 ] || s="${s}."

			f_date="$("${EASYTLS_DATE}" +%s -r "${fixed_md_file}_${i}")"

			# shellcheck disable=SC2154
			if [ $((local_date_sec - f_date)) -gt ${EASYTLS_STALE_SEC} ]; then
				"${EASYTLS_RM}" "${fixed_md_file}_${i}" || stack_err=1
				update_status "stack-down: ${i} STALE"
				tlskey_status "  | =$ stack:- ${s}${i} STALE -"
				stale_error "${local_date_ascii} ${fixed_md_file}_${i}"
			fi
		else
			break
		fi
	done

	f_date="$("${EASYTLS_DATE}" +%s -r "${fixed_md_file}")"
	if [ $((local_date_sec - f_date)) -gt ${EASYTLS_STALE_SEC} ]; then
		"${EASYTLS_RM}" "${fixed_md_file}" || stack_err=1
		update_status "stack-down: clear"
		tlskey_status "  | =  stack: clear -"
		stale_error "${local_date_ascii} ${fixed_md_file}"
	fi

	# Unlock
	release_lock "${easytls_lock_stub}-stack.d" || \
		die "release_lock:stack FAIL" 99
	update_status "stack-lock-released"

	[ ! $stack_err ] || die "STACK_DOWN_FULL_ERROR" 160
} # => stack_down ()

# Log stale files
stale_error ()
{
	[ $ENABLE_STALE_LOG ] || return 0
	"${EASYTLS_PRINTF}" '%s\n' "${1}" >> "${EASYTLS_SE_XLOG}"
}

# TLSKEY tracking .. because ..
tlskey_status ()
{
	[ $EASYTLS_TLSKEY_STATUS ] || return 0
	{
		# shellcheck disable=SC2154
		"${EASYTLS_PRINTF}" '%s %s %s %s\n' "${local_date_ascii}" \
			"${UV_TLSKEY_SERIAL:-TLSAC}" "[dis]${1}" \
			"${common_name} ${UV_REAL_NAME}"
	} >> "${EASYTLS_TK_XLOG}"
} # => tlskey_status ()

# Retry pause
retry_pause ()
{
	if [ $EASYTLS_FOR_WINDOWS ]
	then
		ping -n 1 127.0.0.1
	else
		sleep 1
	fi
} # => retry_pause ()

# Simple lock dir
acquire_lock ()
{
	[ -n "${1}" ] || return 1
	unset lock_acquired
	lock_attempt=9
	set -o noclobber
	while [ ${lock_attempt} -gt 0 ]; do
		[ ${lock_attempt} -eq 9 ] || retry_pause
		lock_attempt=$(( lock_attempt - 1 ))
		"${EASYTLS_MKDIR}" "${1}" || continue
		lock_acquired=1
		break
	done
	set +o noclobber
	[ $lock_acquired ] || return 1
} # => acquire_lock ()

# Release lock
release_lock ()
{
	[ -d "${1}" ] || return 0
	"${EASYTLS_RM}" -d "${1}"
} # => release_lock ()

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# Defaults
	EASYTLS_srv_pid=$PPID
	ENABLE_STACK=1
	unset -v LOAD_VARS VARS_FILE

	# Log message
	status_msg="* EasyTLS-client-disconnect"

	# Identify Windows
	# shellcheck disable=SC2016
	EASYRSA_KSH='@(#)MIRBSD KSH R39-w32-beta14 $Date: 2013/06/28 21:28:57 $'
	[ "${KSH_VERSION}" = "${EASYRSA_KSH}" ] && EASYTLS_FOR_WINDOWS=1

	# Required binaries
	EASYTLS_OPENSSL='openssl'
	EASYTLS_AWK='awk'
	EASYTLS_CAT='cat'
	EASYTLS_DATE='date'
	EASYTLS_GREP='grep'
	EASYTLS_MKDIR='mkdir'
	EASYTLS_MV='mv'
	EASYTLS_SED='sed'
	EASYTLS_PRINTF='printf'
	EASYTLS_RM='rm'

	# Directories and files
	if [ $EASYTLS_FOR_WINDOWS ]; then
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
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_MKDIR}.exe" ] || exit 72
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_MV}.exe" ] || exit 71
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_SED}.exe" ] || exit 68
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_PRINTF}.exe" ] || exit 69
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_RM}.exe" ] || exit 70

		export PATH="${EASYTLS_ersabin_dir};${EASYTLS_ovpnbin_dir};${PATH}"
	fi
} # => init ()

# Dependancies
deps ()
{
	if [ $EASYTLS_FOR_WINDOWS ]; then
		WIN_TEMP="${host_drv}:/Windows/Temp"
		export EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-${WIN_TEMP}}"
	else
		export EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-/tmp}"
	fi

	# Test temp dir
	[ -d "${EASYTLS_tmp_dir}" ] || exit 60

	# Temp files name stub
	temp_stub="${EASYTLS_tmp_dir}/easytls-${EASYTLS_srv_pid}"

	# Lock dir
	easytls_lock_stub="${temp_stub}-lock"

	# Need the date/time ..
	full_date="$("${EASYTLS_DATE}" '+%s %Y/%m/%d-%H:%M:%S')"
	local_date_ascii="${full_date##* }"
	local_date_sec="${full_date%% *}"

	# Windows log
	EASYTLS_WLOG="${temp_stub}-client-disconnect.log"

	# Xtra logs - TLS Key status & Stack Errors
	EASYTLS_TK_XLOG="${temp_stub}-tcv2-ct.x-log"
	EASYTLS_SE_XLOG="${temp_stub}-tcv2-se.x-log"

	# Temp file age before stale
	EASYTLS_STALE_SEC="${EASYTLS_STALE_SEC:-240}"

	# Source metadata lib
	prog_dir="${0%/*}"
	lib_file="${prog_dir}/easytls-metadata.lib"
	[ -f "${lib_file}" ] || die "Missing ${lib_file}" 71
	# shellcheck source=./easytls-metadata.lib
	. "${lib_file}"
	unset -v lib_file

	# Conn track
	EASYTLS_CONN_TRAC="${temp_stub}-conn-trac"

	# Kill server file
	[ -f "${temp_stub}-die" ] && echo "Kill Server Signal -> exit CD" && exit 9

	# Kill client file
	EASYTLS_KILL_FILE="${temp_stub}-kill-client"
}



#######################################

# Initialise
init

# Options
while [ -n "${1}" ]; do
	# Separate option from value:
	opt="${1%%=*}"
	val="${1#*=}"
	empty_ok="" # Empty values are not allowed unless expected

	case "${opt}" in
	help|-h|--help)
		empty_ok=1
		help_text
	;;
	-V|--version)
			easytls_version
			exit 9
	;;
	-l)
		LOAD_VARS=1
		VARS_FILE="${val}"
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
		if [ -f "${opt}" ]; then
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

# Report and die on fatal warnings
warn_die

# Source vars file
if [ $LOAD_VARS ]
then
	[ -f "${VARS_FILE}" ] || die "source missing: ${VARS_FILE}" 78
	# shellcheck source=./easytls-client-disconnect.vars-example
	. "${VARS_FILE}" || die "source failed: ${VARS_FILE}" 77
	update_status "vars loaded"
	unset -v LOAD_VARS VARS_FILE
fi

# Dependencies
deps

# Write env file
[ $WRITE_ENV ] && {
	env_file="${temp_stub}-client-disconnect.env"
	if [ $EASYTLS_FOR_WINDOWS ]; then
		set > "${env_file}"
	else
		env > "${env_file}"
	fi
	unset -v env_file
	}

# Update log message
# shellcheck disable=SC2154 # common_name
update_status "CN: ${common_name}"

# Set Client certificate serial number from Openvpn env
# shellcheck disable=SC2154
client_serial="$(format_number "${tls_serial_hex_0}")"

# Verify Client certificate serial number
[ -z "${client_serial}" ] && {
	help_note="Openvpn failed to pass a client serial number"
	die "NO CLIENT SERIAL" 8
	}

# Fixed file for TLS-CV2
if [ -n "${UV_TLSKEY_SERIAL}" ]; then
	fixed_md_file="${temp_stub}-tcv2-metadata-${UV_TLSKEY_SERIAL}"
	update_status "tls key serial: ${UV_TLSKEY_SERIAL}"
else
	no_uv_tlskey_serial=1
fi

# Clear old stack now - because there is still a stack problem
# Could be the script or openvpn
if [ $no_uv_tlskey_serial ]; then
	# TLS-AUTH/Crypt does not stack up
	:
else
	stack_down || die "stack_down FAIL" 165
fi

# disconnect can not fail ..
disconnect_accepted

# conntrac disconnect
if [ $ENABLE_CONN_TRAC ]; then
	update_conntrac || die "update_conntrac" 170
else
	#update_status "conn-trac disabled"
	:
fi

# Any failure_msg means fail_and_exit
[ -n "${failure_msg}" ] && fail_and_exit "NEIN: ${failure_msg}" 9

# For DUBUG
[ "${FORCE_ABSOLUTE_FAIL}" ] && \
	absolute_fail=1 && failure_msg="FORCE_ABSOLUTE_FAIL"

# There is only one way out of this...
if [ $absolute_fail -eq 0 ]; then
	# Delete all temp files
	delete_metadata_files

	# TLSKEY disconnect log
	tlskey_status "<<     D-OK"

	# All is well
	verbose_print "${local_date_ascii} <EXOK> ${status_msg}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n" \
		"${status_msg}" > "${EASYTLS_WLOG}"
	exit 0
fi

# Otherwise
fail_and_exit "ABSOLUTE FAIL" 9
