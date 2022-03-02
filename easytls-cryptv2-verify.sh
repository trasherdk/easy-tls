#!/bin/sh

EASYTLS_VERSION="2.8.0"

# Copyright - negotiable
#
# VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-cryptv2-verify.sh -- Do simple magic
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
# Verify:
#   metadata version
#   metadata custom group
#   TLS key age
#   Identity (CA Fingerprint)
#   disabled list
#   Client certificate serial number
#     * via certificate revokation list (Default)
#     * via OpenSSL CA (Not recommended)
#     * via OpenSSL index.txt (Preferred)
#
# VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
#

# Help
help_text ()
{
	help_msg="
  easytls-cryptv2-verify.sh

  This script is intended to be used by tls-crypt-v2 client keys
  generated by Easy-TLS.  See: https://github.com/TinCanTech/easy-tls

  Options:
  help|-h|--help         This help text.
  -V|--version
  -v|--verbose           Be a lot more verbose at run time (Not Windows).
  -c|--ca=<DIR>          CA directory *REQUIRED*
  -z|--no-ca             Run in No CA mode. Still requires --ca=<DIR>
  -g|--custom-group=<GROUP>
                         Verify the client metadata against a custom group.
  -s|--source-vars=<FILENAME>
                         Force Easy-TLS to source a vars file.
                         The default vars file is sourced if no FILENAME is given.
  -x|--max-tlskey-age=<DAYS>
                         TLS Crypt V2 Key allowable age in days (default: 1825).
                         To disable age check use 0
  -y|--tlskey-hash       Verify metadata hash (TLS-key serial number).
  -d|--disable-list      Disable the temporary disabled-list check.
  -k|--kill-client       Use easytls-client-connect script to kill client.
                         Killing a client can only be done once a client has
                         connected, so a failed connection must roll-over, then
                         easytls-client-connect.sh immediately kills the client.
  --v1|--via-crl         Do X509 certificate checks via X509_METHOD 1, CRL check.
  --v2|--via-ca          Do X509 certificate checks via X509_METHOD 2,
                         Use 'OpenSSL ca' commands.  NOT SUPPORTED
  --v3|--via-index       Do X509 certificate checks via X509_METHOD 3,
                         Search OpenSSL index.txt  PREFERRED
                         This method does not require loading the OpenSSL binary.
  -a|--cache-id          Use the saved CA-Identity from EasyTLS.
  -p|--preload-id=<CA-ID>
                         Preload the CA-Identity when calling the script.
  -w|--work-dir=<DIR>    Path to Easy-TLS scripts and vars for this server.
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
  0   - Allow connection, Client key has passed all tests.
  2   - Disallow connection, client key has passed all tests but is REVOKED.
  3   - Disallow connection, TLS key serial number is disabled.
  4   - Disallow connection, TLS key has expired.
  5   - Disallow connection, local/remote Custom Groups do not match.
  6   - Disallow connection, local/remote Identities do not match.
  7   - Disallow connection, invalid metadata_version field.
  8   - Dissalow connection, failed to read metadata_file
  9   - BUG Disallow connection, general script failure.
  10  - ERROR Disallow connection, client TLS key has unknown serial number.
  11  - ERROR Disallow connection, client TLS key has invalid serial number.
  12  - ERROR Disallow connection, missing remote Identity.
  13  - ERROR Disallow connection, missing local Identity. (Unlucky)
  21  - USER ERROR Disallow connection, options error.
  22  - USER ERROR Disallow connection, failed to set --ca <PATH> *REQUIRED*.
  23  - USER ERROR Disallow connection, missing CA certificate.
  24  - USER ERROR Disallow connection, missing CRL file.
  25  - USER ERROR Disallow connection, missing index.txt.
  26  - USER ERROR Disallow connection, missing safessl-easyrsa.cnf.
  27  - USER ERROR Disallow connection, missing EasyTLS disabled list.
  28  - USER ERROR Disallow connection, missing openvpn server metadata_file.
  29  - USER ERROR Disallow connection, Invalid value for --tls-age.
  30  - USER ERROR Disallow connection, missing EasyTLS data dir.
  33  - USER ERROR Disallow connection, missing EasyTLS CA Identity file.
  34  - USER ERROR Disallow connection, Invalid --cache-id and --preload-cache-id
  35  - USER ERROR Disallow connection, missing easy-rsa binary directory.
  36  - USER ERROR Disallow connection, missing openvpn binary directory.
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
  72  - USER ERROR Disallow connection, missing mkdir.exe

  77  - BUG Disallow connection, failed to sources vars file
  78  - USER ERROR Disallow connection, missing vars file
  89  - BUG Disallow connection, failed to create client_md_file_stack
  101 - BUG Disallow connection, stale metadata file.
  112 - BUG Disallow connection, invalid date
  113 - BUG Disallow connection, missing dependency file.
  114 - BUG Disallow connection, missing dependency file.
  115 - BUG Disallow connection, missing dependency file.
  116 - BUG Disallow connection, missing dependency file.
  117 - BUG Disallow connection, missing dependency file.
  118 - BUG Disallow connection, missing dependency file.
  119 - BUG Disallow connection, missing dependency file.
  121 - BUG Disallow connection, client serial number is not in CA database.
  122 - BUG Disallow connection, failed to verify CRL.
  123 - BUG Disallow connection, failed to verify CA.
  127 - BUG Disallow connection, duplicate serial number in CA database.
  128 - BUG Disallow connection, duplicate serial number in CA database. v2
  129 - BUG Disallow connection, Serial status via CA has broken.
  130 - BUG Disallow connection, unknown X509 method.
  253 - Disallow connection, exit code when --help is called.
  254 - BUG Disallow connection, fail_and_exit exited with default error code.
  255 - BUG Disallow connection, die exited with default error code.
"
	print "$help_msg"

	# For secrity, --help must exit with an error
	exit 253
} # => help_text ()

# Wrapper around 'printf' - clobber 'print' since it's not POSIX anyway
# shellcheck disable=SC1117
print () { "${EASYTLS_PRINTF}" "%s\n" "${1}"; }
verbose_print ()
{
	[ -n "${EASYTLS_VERBOSE}" ] || return 0
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

	#delete_metadata_files
	easytls_version
	[ -n "${help_note}" ] && print "${help_note}"
	[ -n "${err_msg}" ] && print "${err_msg}"
	verbose_print "<ERROR> ${status_msg}"
	print "ERROR: ${1}"
	if [ -n "${ENABLE_KILL_SERVER}" ]; then
		echo 1 > "${temp_stub}-die"
		echo 'XXXXX CV2 XXXXX KILL SERVER'
		if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
			"${EASYTLS_PRINTF}" "%s\n%s\n" \
				"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
			taskkill /F /PID "${EASYTLS_srv_pid}"
		else
			kill -15 "${EASYTLS_srv_pid}"
		fi
	fi
	exit "${2:-255}"
}

# Tls-crypt-v2-verify failure, not an error.
fail_and_exit ()
{
	# Unlock
	if release_lock "${easytls_lock_stub}-v2.d"; then
		update_status "v2-lock-released"
	else
		update_status "v2-fail_and_exit:release_lock-FAIL"
	fi

	delete_metadata_files

	# shellcheck disable=SC2154
	if [ -n "${EASYTLS_VERBOSE}" ]; then
		print "${status_msg}"
		print "${failure_msg}"
		print "${1}"
		print "* ==> version       local: ${local_easytls}"
		print "* ==> version      remote: ${MD_EASYTLS}"
		print "* ==> custom_group  local: ${LOCAL_CUSTOM_G}"
		print "* ==> custom_group remote: ${MD_CUSTOM_G}"
		print "* ==> identity      local: ${local_identity}"
		print "* ==> identity     remote: ${MD_IDENTITY}"
		print "* ==> X509 serial  remote: ${MD_x509_SERIAL}"
		print "* ==> name         remote: ${MD_NAME}"
		print "* ==> TLSK serial  remote: ${MD_TLSKEY_SERIAL}"
		print "* ==> sub-key      remote: ${MD_SUBKEY}"
		print "* ==> date         remote: ${MD_DATE}"
		[ "${2}" -eq 2 ] && print "* ==> Client serial status: revoked"
		[ "${2}" -eq 3 ] && print "* ==> Client serial status: disabled"
		[ -n "${help_note}" ] && print "${help_note}"
	else
		print "${status_msg}"
		print "${failure_msg}"
		print "${1}"
	fi

	# TLSKEY connect log
	tlskey_status "*V!  FAIL" || update_status "tlskey_status FAIL"

	[ -n "${EASYTLS_FOR_WINDOWS}" ] && "${EASYTLS_PRINTF}" "%s %s %s %s\n" \
		"<FAIL> ${status_msg}" "${failure_msg}" "${1}" \
			"ENABLE_KILL_CLIENT: ${ENABLE_KILL_CLIENT:-0}" > "${EASYTLS_WLOG}"

	[ -n "${ENABLE_KILL_CLIENT}" ] && {
		# Create kill client file
		"${EASYTLS_PRINTF}" "%s\n" "${MD_x509_SERIAL}" > "${EASYTLS_KILL_FILE}"
		# Create metadata file for client-connect or kill-client
		write_metadata_file
		# Exit without error to kill client
		exit 0
		}

	exit "${2:-254}"
} # => fail_and_exit ()

# Delete all metadata files
delete_metadata_files ()
{
	[ -n "${keep_metadata}" ] || {
		"${EASYTLS_RM}" -f "${client_md_file_stack}"
		update_status "temp-files deleted"
		}
}

# Log fatal warnings
warn_die ()
{
	if [ -n "${1}" ]; then
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

# Verify CA
verify_ca ()
{
	"${EASYTLS_OPENSSL}" x509 -in "${ca_cert}" -noout
}

# Local identity
fn_local_identity ()
{
	"${EASYTLS_OPENSSL}" x509 -in "${ca_cert}" \
		-noout -SHA256 -fingerprint | \
			"${EASYTLS_SED}" -e 's/^.*=//g' -e 's/://g'
}

# Verify CRL
verify_crl ()
{
	"${EASYTLS_OPENSSL}" crl -in "${crl_pem}" -noout
}

# Decode CRL
fn_read_crl ()
{
	"${EASYTLS_OPENSSL}" crl -in "${crl_pem}" -noout -text
}

# Search CRL for client cert serial number
fn_search_crl ()
{
	"${EASYTLS_PRINTF}" "%s\n" "${crl_text}" | \
		"${EASYTLS_GREP}" -c "^[[:blank:]]*Serial Number: ${MD_x509_SERIAL}$"
}

# Final check: Search index.txt for Valid client cert serial number
fn_search_index ()
{
	"${EASYTLS_GREP}" -c \
		"^V.*[[:blank:]]${MD_x509_SERIAL}[[:blank:]].*/CN=${MD_NAME}.*$" \
		"${index_txt}"
}

# Check metadata client certificate serial number against CRL
serial_status_via_crl ()
{
	client_cert_revoked="$(fn_search_crl)"
	case "${client_cert_revoked}" in
	0)
		# Final check: Is this serial in index.txt and Valid
		case "$(fn_search_index)" in
		0)
		failure_msg="Serial number is not in the CA database:"
		fail_and_exit "SERIAL NUMBER UNKNOWN" 121
		;;
		1)
		client_passed_x509_tests
		;;
		*)
		die "Duplicate serial numbers: ${MD_x509_SERIAL}" 127
		;;
		esac
	;;
	1)
		client_passed_x509_tests_certificate_revoked
	;;
	*)
		insert_msg="Duplicate serial numbers detected:"
		failure_msg="${insert_msg} ${MD_x509_SERIAL}"
		die "Duplicate serial numbers: ${MD_x509_SERIAL}" 128
	;;
	esac
}

# Check metadata client certificate serial number against CA
serial_status_via_ca ()
{
	# This is non-functional until OpenSSL is fixed
	verify_openssl_serial_status

	# Get serial status via CA
	# Forget that returns an error because of OpenSSL
	client_cert_serno_status="$(openssl_serial_status)"

	# Format serial status
	# Deliberately over-write the previous value
	client_cert_serno_status="$(capture_serial_status)"
	client_cert_serno_status="${client_cert_serno_status% *}"
	client_cert_serno_status="${client_cert_serno_status##*=}"


	# Considering what has to be done, I don't like this
	case "${client_cert_serno_status}" in
	Valid)
		client_passed_x509_tests
	;;
	Revoked)
		client_passed_x509_tests_certificate_revoked
	;;
	*)
		die "Serial status via CA has broken" 129
	;;
	esac
}

# Use OpenSSL to return certificate serial number status
openssl_serial_status ()
{
	# OpenSSL ALWAYS exit with error - but here I do not care
	# And will NOT defend against error
	"${EASYTLS_OPENSSL}" ca -cert "${ca_cert}" -config "${openssl_cnf}" \
		-status "${MD_x509_SERIAL}" 2>&1
}

# Capture serial status
capture_serial_status ()
{
	"${EASYTLS_PRINTF}" "%s\n" "${client_cert_serno_status}" | \
		"${EASYTLS_GREP}" '^.*=.*$'
}

# Verify OpenSSL serial status returns ok
verify_openssl_serial_status ()
{
	return 0 # Disable this `return` if you want to test
	# OpenSSL appears to always exit with error - have not solved this
	# OpenSSL 3.0.1 is just as obtuse ..
	"${EASYTLS_OPENSSL}" ca -cert "${ca_cert}" -config "${openssl_cnf}" \
		-status "${MD_x509_SERIAL}" || \
		die "OpenSSL returned an error exit code" 101

# This is why I am not using CA, from `man 1 ca`
: << MAN_OPENSSL_CA
WARNINGS
       The ca command is quirky and at times downright unfriendly.

       The ca utility was originally meant as an example of how to do things
       in a CA. It was not supposed to be used as a full blown CA itself:
       nevertheless some people are using it for this purpose.

       The ca command is effectively a single user command: no locking is
       done on the various files and attempts to run more than one ca command
       on the same database can have unpredictable results.
MAN_OPENSSL_CA
# This script ONLY reads, .:  I am hoping for better than 'unpredictable' ;-)
}

# Check metadata client certificate serial number against index.txt
serial_status_via_pki_index ()
{
	# This needs improvement
	is_valid="$(fn_search_valid_pki_index)"
	is_revoked="$(fn_search_revoked_pki_index)"
	if [ "${is_revoked}" -eq 0 ]; then
		if [ "${is_valid}" -eq 1 ]; then
			client_passed_x509_tests
		else
			# Cert is not known
			insert_msg="Serial number is not in the CA database:"
			failure_msg="${insert_msg} ${MD_x509_SERIAL}"
			fail_and_exit "SERIAL NUMBER UNKNOWN" 121
		fi
	else
		client_passed_x509_tests_certificate_revoked
	fi
}

# Final check: Search index.txt for Valid client cert serial number
fn_search_valid_pki_index ()
{
	"${EASYTLS_GREP}" -c \
	"^V.*[[:blank:]]${MD_x509_SERIAL}[[:blank:]].*\/CN=${MD_NAME}.*$" \
		"${index_txt}"
}

# Final check: Search index.txt for Revoked client cert serial number
fn_search_revoked_pki_index ()
{
	"${EASYTLS_GREP}" -c \
	"^R.*[[:blank:]]${MD_x509_SERIAL}[[:blank:]].*\/CN=${MD_NAME}.*$" \
		"${index_txt}"
}

# This is the long way to connect - X509
client_passed_x509_tests ()
{
	insert_msg="Client certificate is recognised and Valid:"
	update_status "${insert_msg} ${MD_x509_SERIAL}"
}

# This is the only way to fail for Revokation - X509
client_passed_x509_tests_certificate_revoked ()
{
	insert_msg="Client certificate is revoked:"
	failure_msg="${insert_msg} ${MD_x509_SERIAL}"
	fail_and_exit "CERTIFICATE REVOKED" 2
}

# This is the best way to connect - TLS only
client_passed_tls_tests_connection_allowed ()
{
	absolute_fail=0
	update_status "connection allowed"
}

# Allow connection
connection_allowed ()
{
	absolute_fail=0
	update_status "connection allowed"
}

# Retry pause
retry_pause ()
{
	if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
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
	lock_attempt="${LOCK_TIMEOUT}"
	set -o noclobber
	while [ "${lock_attempt}" -gt 0 ]; do
		[ "${lock_attempt}" -eq "${LOCK_TIMEOUT}" ] || retry_pause
		lock_attempt=$(( lock_attempt - 1 ))
		"${EASYTLS_MKDIR}" "${1}" || continue
		lock_acquired=1
		break
	done
	set +o noclobber
	[ -n "${lock_acquired}" ] || return 1
} # => acquire_lock ()

# Release lock
release_lock ()
{
	[ -d "${1}" ] || return 0
	"${EASYTLS_RM}" -r "${1}"
} # => release_lock ()

# Write metadata file
write_metadata_file ()
{
	# Set the client_md_file_stack
	client_md_file_stack="${temp_stub}-tcv2-metadata-${MD_TLSKEY_SERIAL}"

	# Lock
	acquire_lock "${easytls_lock_stub}-stack.d" || \
		die "acquire_lock:stack FAIL" 99
	update_status "stack-lock-acquired"

	# Stack up duplicate metadata files - check for stale_stack
	unset stale_stack
	if [ -f "${client_md_file_stack}" ]; then
		stack_up || die "stack_up" 160
	fi

	if [ -n "${stale_stack}" ]; then
		update_status "stale_stack"
		if [ -n "${ENABLE_STALE_LOG}" ]; then
			EASYTLS_stale_log="${temp_stub}-stale.x-log"
			"${EASYTLS_PRINTF}" '%s\n' \
				"${local_date_ascii} - ${client_md_file_stack}" \
					>> "${EASYTLS_stale_log}" || :
		fi
	else
		if [ -f "${client_md_file_stack}" ]; then
			# If client_md_file_stack still exists then fail
			update_status "STALE_FILE_ERROR"
			keep_metadata=1
			die "STALE_FILE_ERROR" 101
		else
			# Otherwise stack-up
			"${EASYTLS_MV}" "${OPENVPN_METADATA_FILE}" \
				"${client_md_file_stack}" || \
					die "Failed to update client_md_file_stack" 89
			update_status "Created client_md_file_stack"
		fi
	fi

	# Lock
	release_lock "${easytls_lock_stub}-stack.d" || \
		die "release_lock:stack FAIL" 99
	update_status "stack-lock-released"
} # => write_metadata_file ()

# Stack up
stack_up ()
{
	[ -n "${stack_completed}" ] && die "STACK_UP CAN ONLY RUN ONCE" 161
	stack_completed=1

	# No Stack UP - No stack in stand alone mode
	[ -n "${EASYTLS_STAND_ALONE}" ] && return 0

	f_date="$("${EASYTLS_DATE}" +%s -r "${client_md_file_stack}")"
	unset stale_stack
	if [ $(( local_time_unix - f_date )) -gt 60 ]; then
		stale_stack=1
		return 0
	fi

	# Full Stack UP
	i=1
	s=''
	while [ -f "${client_md_file_stack}_${i}" ]; do
		s="${s}."
		i=$(( i + 1 ))
	done
	client_md_file_stack="${client_md_file_stack}_${i}"
	s="${s}${i}"

	update_status "stack-up"
	tlskey_status "  | => stack:+ ${s} -"
} # => stack_up ()

# TLSKEY tracking .. because ..
tlskey_status ()
{
	[ -n "${EASYTLS_TLSKEY_STATUS}" ] || return 0
	{
		# shellcheck disable=SC2154
		"${EASYTLS_PRINTF}" '%s %s %s %s\n' "${local_date_ascii}" \
			"${MD_TLSKEY_SERIAL}" "*VF >${1}" "${MD_NAME}"
	} >> "${EASYTLS_TK_XLOG}"
} # => tlskey_status ()

# easytls-metadata.lib
#=# 35579017-b084-4d6b-94d5-76397c2d4a1f

# Break metadata_string into variables
# shellcheck disable=SC2034 # foo appears unused. Verify it or export it.
metadata_string_to_vars ()
{
	MD_TLSKEY_SERIAL="${1%%-*}" || return 1

	#seed="${*}" || return 1
	#MD_SEED="${seed#*-}" || return 1
	#unset -v seed

	#md_padding="${md_seed%%--*}" || return 1
	md_easytls_ver="${1#*--}" || return 1
	MD_EASYTLS="${md_easytls_ver%-*}" || return 1
	unset -v md_easytls_ver

	MD_IDENTITY="${2%%-*}" || return 1
	MD_SRV_NAME="${2##*-}" || return 1
	MD_x509_SERIAL="${3}" || return 1
	MD_DATE="${4}" || return 1
	MD_CUSTOM_G="${5}" || return 1
	MD_NAME="${6}" || return 1
	MD_SUBKEY="${7}" || return 1
	MD_OPT="${8}" || return 1
	MD_FILTERS="${9}" || return 1
} # => metadata_string_to_vars ()

# Break metadata string at delimeter: New Newline, old space
# shellcheck disable=SC2034 # foo appears unused. Verify it or export it.
metadata_stov_safe ()
{
	[ -n "$1" ] || return 1
	input="$1"

	# Not using IFS
	err_msg="Unspecified delimiter"
	delim_save="${delimiter}"
	delimiter="${delimiter:-${newline}}"
	[ -n "${delimiter}" ] || return 1
	case "${input}" in
		*"${delimiter}"*) : ;;
		*) delimiter=' '
	esac

	MD_SEED="${input#*-}"

	# Expansions inside ${..} need to be quoted separately,
	# otherwise they will match as a pattern.
	# Which is the required behaviour.
	# shellcheck disable=SC2295
	{	# Required group for shellcheck
		m1="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
		m2="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
		m3="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
		m4="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
		m5="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
		m6="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
		m7="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
		m8="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
		m9="${input%%${delimiter}*}"
		input="${input#*${delimiter}}"
	}

	# An extra space has been used, probably in the name
	err_msg="metadata-lib: ${m9} vs ${input}"
	[ "${m9}" = "${input}" ] || return 1

	delimiter="${delim_save}"

	err_msg="metadata-lib: metadata_string_to_vars"
	metadata_string_to_vars "$m1" "$m2" "$m3" "$m4" \
		"$m5" "$m6" "$m7" "$m8" "$m9" || return 1
	unset -v m1 m2 m3 m4 m5 m6 m7 m8 m9 input err_msg
} # => metadata_stov_safe ()

#=# 70b4ec32-f1fc-47fb-a261-f02e7f572b62

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1
	delimiter='
'

	# metadata version
	local_easytls='easytls'

	# TLS expiry age (days) Default 5 years, 1825 days
	TLSKEY_MAX_AGE=$((365*5))

	# Defaults
	if [ -z "${EASYTLS_UNIT_TEST}" ]; then
		EASYTLS_srv_pid="$PPID"
	else
		EASYTLS_srv_pid=999
	fi

	# metadata file
	# shellcheck disable=SC2154
	OPENVPN_METADATA_FILE="${metadata_file}"

	# Log message
	status_msg="* Easy-TLS-cryptv2-verify"

	# X509 is disabled by default
	# To enable use command line option:
	# --v1|--via-crl   - client serial revokation via CRL search (Default)
	# --v2|--via-ca    - client serial revokation via OpenSSL ca command (Broken)
	# --v3|--via-index - client serial revokation via index.txt search (Preferred)
	X509_METHOD=0

	# Identify Windows
	# shellcheck disable=SC2016
	EASYRSA_KSH='@(#)MIRBSD KSH R39-w32-beta14 $Date: 2013/06/28 21:28:57 $'
	# shellcheck disable=SC2154
	[ "${KSH_VERSION}" = "${EASYRSA_KSH}" ] && EASYTLS_FOR_WINDOWS=1

	# Required binaries
	EASYTLS_OPENSSL='openssl'
	EASYTLS_CAT='cat'
	EASYTLS_CP='cp'
	EASYTLS_DATE='date'
	EASYTLS_GREP='grep'
	EASYTLS_MKDIR='mkdir'
	EASYTLS_MV='mv'
	EASYTLS_SED='sed'
	EASYTLS_PRINTF='printf'
	EASYTLS_RM='rm'

	# Directories and files
	if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
		# Windows
		host_drv="${PATH%%\:*}"
		base_dir="${EASYTLS_base_dir:-${host_drv}:/Progra~1/Openvpn}"
		EASYTLS_ersabin_dir="${EASYTLS_ersabin_dir:-${base_dir}/easy-rsa/bin}"
		EASYTLS_ovpnbin_dir="${EASYTLS_ovpnbin_dir:-${base_dir}/bin}"

		[ -d "${base_dir}" ] || exit 61
		[ -d "${EASYTLS_ersabin_dir}" ] || exit 62
		[ -d "${EASYTLS_ovpnbin_dir}" ] || exit 63
		[ -f "${EASYTLS_ovpnbin_dir}/${EASYTLS_OPENSSL}.exe" ] || exit 64
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_CAT}.exe" ] || exit 65
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_CP}.exe" ] || exit 65
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
	# OpenVPN only provides a minimal shell for --tls-crypt-v2
	# Thus, this extra loop to jump through to source vars
	# Also, vars MUST be loaded successfully.
	# Source vars file
	prog_dir="${0%/*}"
	EASYTLS_WORK_DIR="${EASYTLS_WORK_DIR:-${prog_dir}}"
	default_vars="${EASYTLS_WORK_DIR}/easytls-cryptv2-verify.vars"
	EASYTLS_VARS_FILE="${EASYTLS_VARS_FILE:-${default_vars}}"
	if [ -f "${EASYTLS_VARS_FILE}" ]; then
		# .vars-example is correct for shellcheck
		# shellcheck source=examples/easytls-cryptv2-verify.vars-example
		. "${EASYTLS_VARS_FILE}" || die "Source failed: ${EASYTLS_VARS_FILE}" 77
		update_status "vars loaded"
	else
		[ -n "${EASYTLS_REQUIRE_VARS}" ] && \
			die "Missing file: ${EASYTLS_VARS_FILE}" 77
	fi

	# Source metadata lib
	lib_file="${EASYTLS_WORK_DIR}/easytls-metadata.lib"
	[ -f "${lib_file}" ] || \
		lib_file="${EASYTLS_WORK_DIR}/dev/easytls-metadata.lib"
	if [ -f "${lib_file}" ]; then
		# shellcheck source=dev/easytls-metadata.lib
		. "${lib_file}" || die "Failed to source: ${lib_file}"
		easytls_metadata_lib_ver
	fi

	unset -v default_vars EASYTLS_VARS_FILE EASYTLS_REQUIRE_VARS prog_dir lib_file

	if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
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
	LOCK_TIMEOUT="${LOCK_TIMEOUT:-30}"

	# Lock
	acquire_lock "${easytls_lock_stub}-v2.d" || \
		die "acquire_lock:v2 FAIL" 99
	update_status "V2-lock-acquired"

	# Windows log
	EASYTLS_WLOG="${temp_stub}-cryptv2-verify.log"
	EASYTLS_TK_XLOG="${temp_stub}-tcv2-ct.x-log"

	# Kill client file
	EASYTLS_KILL_FILE="${temp_stub}-kill-client"

	# HASH
	EASYTLS_HASH_ALGO="${EASYTLS_HASH_ALGO:-SHA256}"

	# CA_DIR MUST be set with option: -c|--ca
	[ -d "${CA_DIR}" ] || die "Path to CA directory is required, see help" 22

	# Easy-TLS required files
	TLS_dir="${CA_DIR}/easytls/data"
	disabled_list="${TLS_dir}/easytls-disabled-list.txt"
	tlskey_serial_index="${TLS_dir}/easytls-key-index.txt"

	# Check TLS files
	[ -d "${TLS_dir}" ] || {
		help_note="Use './easytls init [no-ca]"
		die "Missing EasyTLS dir: ${TLS_dir}" 30
		}

	# CA required files
	ca_cert="${CA_DIR}/ca.crt"
	ca_identity_file="${TLS_dir}/easytls-ca-identity.txt"
	crl_pem="${CA_DIR}/crl.pem"
	index_txt="${CA_DIR}/index.txt"
	openssl_cnf="${CA_DIR}/safessl-easyrsa.cnf"

	# Check X509 files
	if [ -n "${EASYTLS_NO_CA}" ]; then
		# Do not need CA cert
		# Cannot do any X509 verification
		:
	else
		# Need CA cert
		[ -f "${ca_cert}" ] || {
			help_note="This script requires an EasyRSA generated CA."
			die "Missing CA certificate: ${ca_cert}" 23
			}

		if [ -n "${use_cache_id}" ]; then
			# This can soon be deprecated
			[ -f "${ca_identity_file}" ] || {
				help_note="This script requires an EasyTLS generated CA identity."
				die "Missing CA identity: ${ca_identity_file}" 33
				}
		fi

		# Check for either --cache-id or --preload-cache-id
		# Do NOT allow both
		[ -n "${use_cache_id}" ] && [ -n "${PRELOAD_CA_ID}" ] && \
			die "Cannot use --cache-id and --preload-cache-id together." 34

		if [ ! "${X509_METHOD}" -eq 0 ]; then
			# Only check these files if using x509
			[ -f "${crl_pem}" ] || {
				help_note="This script requires an EasyRSA generated CRL."
				die "Missing CRL: ${crl_pem}" 24
				}

			[ -f "${index_txt}" ] || {
				help_note="This script requires an EasyRSA generated DB."
				die "Missing index.txt: ${index_txt}" 25
				}

			[ -f "${openssl_cnf}" ] || {
				help_note="This script requires an EasyRSA generated PKI."
				die "Missing OpenSSL config: ${openssl_cnf}" 26
				}
		fi
	fi # X509 checks

	# Ensure that TLS expiry age is numeric
	case "${TLSKEY_MAX_AGE}" in
		''|*[!0-9]*) # Invalid value
			die "Invalid value for --tls-age: ${TLSKEY_MAX_AGE}" 29
		;;
		*) # Valid value
			# maximum age in seconds
			tlskey_expire_age_sec=$((TLSKEY_MAX_AGE*60*60*24))
		;;
	esac

	# Default CUSTOM_GROUP
	[ -n "${LOCAL_CUSTOM_G}" ] || LOCAL_CUSTOM_G='EASYTLS'

	# Need the date/time ..
	full_date="$("${EASYTLS_DATE}" '+%s %Y/%m/%d-%H:%M:%S')"
	local_date_ascii="${full_date##* }"
	local_time_unix="${full_date%% *}"

	# Must be set by openvpn
	# If the script fails for metadata file then
	# - All pre-flight checks completed
	# - Script is ready to run
	[ -f "${OPENVPN_METADATA_FILE}" ] || {
		help_note="This script can ONLY be used by a running openvpn server."
		die "Missing: OPENVPN_METADATA_FILE: ${OPENVPN_METADATA_FILE}" 28
		}
} # => deps ()

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
		help_text
	;;
	-V|--version)
		easytls_version
		exit 9
	;;
	-v|--verbose)
		empty_ok=1
		EASYTLS_VERBOSE=1
	;;
	-l)
		empty_ok=1
		EASYTLS_STAND_ALONE=1
	;;
	-c|--ca)
		CA_DIR="${val}"
	;;
	-z|--no-ca)
		empty_ok=1
		EASYTLS_NO_CA=1
	;;
	-w|--work-dir)
		EASYTLS_WORK_DIR="${val}"
	;;
	-s|--source-vars)
		empty_ok=1
		EASYTLS_REQUIRE_VARS=1
		case "${val}" in
			-s|--source-vars)
				unset EASYTLS_VARS_FILE ;;
			*)
				EASYTLS_VARS_FILE="${val}" ;;
		esac
	;;
	-g|--custom-group)
		if [ -z "${LOCAL_CUSTOM_G}" ]; then
			LOCAL_CUSTOM_G="${val}"
		else
			ENABLE_MULTI_CUSTOM_G=1
			LOCAL_CUSTOM_G="${val} ${LOCAL_CUSTOM_G}"
		fi
	;;
	-x|--max-tlskey-age)
		TLSKEY_MAX_AGE="${val}"
	;;
	-d|--disable-list)
		empty_ok=1
		IGNORE_DISABLED_LIST=1
	;;
	-k|--kill-client) # Use client-connect to kill client
		empty_ok=1
		ENABLE_KILL_CLIENT=1
	;;
	-y|--tlskey-hash)
		empty_ok=1
		ENABLE_TLSKEY_HASH=1
	;;
	--hash)
		EASYTLS_HASH_ALGO="${val}"
	;;
	--v1|--via-crl)
		empty_ok=1
		update_status "(crl)"
		X509_METHOD=1
	;;
	--v2|--via-ca)
		empty_ok=1
		update_status "(ca)"
		X509_METHOD=2
	;;
	--v3|--via-index)
		empty_ok=1
		update_status "(index)"
		X509_METHOD=3
	;;
	-a|--cache-id)
		empty_ok=1
		use_cache_id=1
	;;
	-p|--preload-id)
		PRELOAD_CA_ID="${val}"
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="${val}"
	;;
	-b|--base-dir)
		EASYTLS_base_dir="${val}"
	;;
	-o|--openvpn-bin-dir)
		EASYTLS_ovpnbin_dir="${val}"
	;;
	-e|--easyrsa-bin-dir)
		EASYTLS_ersabin_dir="${val}"
	;;
	*)
		warn_die "Unknown option: ${1}"
	;;
	esac

	# fatal error when no value was provided
	if [ -z "${empty_ok}" ] && { [ "${val}" = "${1}" ] || [ -z "${val}" ]; }
	then
		warn_die "Missing value to option: ${opt}"
	fi
	shift
done

# Report and die on fatal warnings
warn_die

# Dependancies
deps

# Write env file
if [ -n "${WRITE_ENV}" ]; then
	env_file="${temp_stub}-cryptv2-verify.env"
	if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
		set > "${env_file}"
	else
		env > "${env_file}"
	fi
	unset -v env_file WRITE_ENV
fi

# Get metadata

	# Get metadata_string
	metadata_string="$("${EASYTLS_CAT}" "${OPENVPN_METADATA_FILE}")"
	[ -z "${metadata_string}" ] && die "failed to read metadata_file" 8

	# Convert metadata string to variables
	metadata_stov_safe  "$metadata_string" || \
		die "metadata_string_to_vars" 87

	# Update log message
	update_status "CN: ${MD_NAME}"

# Metadata version

	# metadata_version MUST equal 'easytls'
	case "${MD_EASYTLS}" in
	"${local_easytls}")
		update_status "${MD_EASYTLS} OK"
	;;
	'')
		failure_msg="metadata version is missing"
		fail_and_exit "METADATA_VERSION" 7
	;;
	*)
		failure_msg="metadata version is not recognised: ${MD_EASYTLS}"
		fail_and_exit "METADATA_VERSION" 7
	;;
	esac

# Metadata custom_group

	if [ -n "${ENABLE_MULTI_CUSTOM_G}" ]; then
		# This will do for the time being ..
		if "${EASYTLS_PRINTF}" "${LOCAL_CUSTOM_G}" | \
			"${EASYTLS_GREP}" -q "${MD_CUSTOM_G}"
		then
			update_status "MULTI custom_group ${MD_CUSTOM_G} OK"
		else
			failure_msg="multi_custom_g"
			fail_and_exit "MULTI_CUSTOM_GROUP" 98
		fi
	else
		# MD_CUSTOM_G MUST equal LOCAL_CUSTOM_G
		case "${MD_CUSTOM_G}" in
		"${LOCAL_CUSTOM_G}")
			update_status "custom_group ${MD_CUSTOM_G} OK"
		;;
		'')
			failure_msg="metadata custom_group is missing"
			fail_and_exit "METADATA_CUSTOM_GROUP" 5
		;;
		*)
			failure_msg="metadata custom_group is not correct: ${MD_CUSTOM_G}"
			fail_and_exit "METADATA_CUSTOM_GROUP" 5
		;;
		esac
	fi

# tlskey-serial checks

	if [ -n "${ENABLE_TLSKEY_HASH}" ]; then
		# Verify tlskey-serial is in index
		"${EASYTLS_GREP}" -q "${MD_TLSKEY_SERIAL}" "${tlskey_serial_index}" || {
			failure_msg="TLS-key is not recognised"
			fail_and_exit "ALIEN MD_TLSKEY_SERIAL" 10
			}

		# HASH metadata sring without the tlskey-serial
		md_hash="$("${EASYTLS_PRINTF}" '%s' "${MD_SEED}" | \
			"${EASYTLS_OPENSSL}" "${EASYTLS_HASH_ALGO}" -r)"
		md_hash="${md_hash%% *}"
		[ "${md_hash}" = "${MD_TLSKEY_SERIAL}" ] || {
			failure_msg="TLS-key metadata hash is incorrect"
			fail_and_exit "MD_TLSKEY_SERIAL" 11
			}

		update_status "tlskey-hash verified OK"
	fi

# tlskey expired

	# Verify key date and expire by --tls-age
	# Disable check if --tls-age=0 (Default age is 5 years)
	if [ "${tlskey_expire_age_sec}" -gt 0 ]; then
		case "${local_time_unix}" in
		''|*[!0-9]*)
			# Invalid value - date.exe is missing
			die "Invalid value for local_time_unix: ${local_time_unix}" 112
		;;
		*) # Valid value
			tlskey_expire_age_sec=$((TLSKEY_MAX_AGE*60*60*24))

			# days since key creation
			tlskey_age_sec=$(( local_time_unix - MD_DATE ))
			tlskey_age_day=$(( tlskey_age_sec / (60*60*24) ))

			# Check key_age is less than --tls-age
			if [ ${tlskey_age_sec} -gt ${tlskey_expire_age_sec} ]
			then
				max_age_msg="Max age: ${TLSKEY_MAX_AGE} days"
				key_age_msg="Key age: ${tlskey_age_day} days"
				failure_msg="Key expired: ${max_age_msg} ${key_age_msg}"
				fail_and_exit "TLSKEY_EXPIRED" 4
			fi

			update_status "Key age ${tlskey_age_day} days OK"
		;;
		esac
	fi

# Disabled list

	# Check serial number is not disabled
	# Use --disable-list to disable this check
	if [ -n "${IGNORE_DISABLED_LIST}" ]; then
		: # Ignored
	else
		[ -f "${disabled_list}" ] || \
			die "Missing disabled list: ${disabled_list}" 27

		# Search the disabled_list for client serial number
		if "${EASYTLS_GREP}" -q "^${MD_TLSKEY_SERIAL}[[:blank:]]" \
			"${disabled_list}"
		then
			# Client is disabled
			failure_msg="TLS key serial number is disabled: ${MD_TLSKEY_SERIAL}"
			fail_and_exit "TLSKEY_DISABLED" 3
		else
			# Client is not disabled
			update_status "Enabled OK"
		fi
	fi


# Start optional X509 checks
if [ "${X509_METHOD}" -eq 0 ]; then
	# No X509 required
	update_status "metadata verified"
else

	# Verify CA cert is valid and/or set the CA identity
	if [ -n "${use_cache_id}" ]; then
		local_identity="$("${EASYTLS_CAT}" "${ca_identity_file}")"
	elif [ -n "${PRELOAD_CA_ID}" ]; then
		local_identity="${PRELOAD_CA_ID}"
	else
		# Verify CA is valid
		verify_ca || die "Bad CA ${ca_cert}" 123

		# Set Local Identity: CA fingerprint
		local_identity="$(fn_local_identity)"
	fi

	# local_identity is required
	[ -z "${local_identity}" ] && {
		failure_msg="Missing: local identity"
		fail_and_exit "LOCAL IDENTITY" 13
		}

	# Check metadata Identity against local Identity
	if [ "${local_identity}" = "${MD_IDENTITY}" ]; then
		update_status "identity OK"
	else
		failure_msg="identity mismatch"
		fail_and_exit "IDENTITY MISMATCH" 6
	fi


	# Verify serial status
	case "${X509_METHOD}" in
	1)
		# Method 1
		# Check metadata client certificate serial number against CRL

		# Verify CRL is valid
		verify_crl || die "Bad CRL: ${crl_pem}" 122

		# Capture CRL
		crl_text="$(fn_read_crl)"

		# Verify via CRL
		serial_status_via_crl
	;;
	2)
		# Method 2
		# Check metadata client certificate serial number against CA

		# Due to OpenSSL being "what it is", it is not possible to
		# reliably verify the 'OpenSSL ca' command (yet..)

		# Verify via CA
		serial_status_via_ca
	;;
	3)
		# Method 3
		# Search OpenSSL index.txt for client serial number
		# and return Valid, Revoked or not Known status
		# OpenSSL is never loaded for this check
		serial_status_via_pki_index
	;;
	*)
		die "Unknown method for verify: ${X509_METHOD}" 130
	;;
	esac

fi # => End optional X509 checks

# Allow connection
connection_allowed

# Any failure_msg means fail_and_exit
[ -n "${failure_msg}" ] && fail_and_exit "NEIN: ${failure_msg}" 9

# For DUBUG
[ "${FORCE_ABSOLUTE_FAIL}" ] && \
	absolute_fail=1 && failure_msg="FORCE_ABSOLUTE_FAIL"

# Create metadata file for client-connect or kill-client
write_metadata_file

# Unlock
release_lock "${easytls_lock_stub}-v2.d" || die "release_lock:v2 FAIL" 99
update_status "v2-lock-released"

# There is only one way out of this...
if [ "${absolute_fail}" -eq 0 ]; then
	# TLSKEY connect log
	tlskey_status ">>:    V-OK" || update_status "tlskey_status FAIL"

	# All is well
	verbose_print "${local_date_ascii} <EXOK> ${status_msg}"
	[ -n "${EASYTLS_FOR_WINDOWS}" ] && "${EASYTLS_PRINTF}" "%s\n" \
		"<EXOK> ${status_msg}" > "${EASYTLS_WLOG}"
	exit 0
fi

# Otherwise
fail_and_exit "ABSOLUTE FAIL" 9
