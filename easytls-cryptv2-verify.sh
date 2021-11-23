#!/bin/sh

	EASYTLS_VERSION="2.6"

# Copyright - negotiable
copyright ()
{
: << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
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
VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
}

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
  -n|--no-hash           Do not verify metadata hash (TLS-key serial number).
  -x|--max-tls-age=<DAYS>
                         TLS Crypt V2 Key allowable age in days (default: 1825).
                         To disable age check use 0
  -d|--disable-list      Disable the temporary disabled-list check.
  -k|--kill-client       Use easytls-client-connect script to kill client.
                         Killing a client can only be done once a client has
                         connected, so a failed connection must roll-over, then
                         easytls-client-connect.sh immediately kills the client.
  -s|--pid-file=<FILE>   The PID file for the openvpn server instance.
  --v1|--via-crl         Do X509 certificate checks via x509_method 1, CRL check.
  --v2|--via-ca          Do X509 certificate checks via x509_method 2,
                         Use 'OpenSSL ca' commands.  NOT SUPPORTED
  --v3|--via-index       Do X509 certificate checks via x509_method 3,
                         Search OpenSSL index.txt  PREFERRED
                         This method does not require loading the OpenSSL binary.
  -a|--cache-id          Use the saved CA-Identity from EasyTLS.
  -p|--preload-id=<CA-ID>
                         Preload the CA-Identity when calling the script.
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

  77  - BUG Disallow connection, failed to sources vars file
  89  - BUG Disallow connection, failed to create client_md_file
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

	#delete_metadata_files
	[ -n "${help_note}" ] && print "${help_note}"
	verbose_print "<ERROR> ${status_msg}"
	print "ERROR: ${1}"
	echo 'XXXXX CV2 XXXXX'
	echo 1 > "${temp_stub}-die"
	if [ $ENABLE_KILL_PPID ]
	then
		if [ $EASYTLS_FOR_WINDOWS ]
		then
			"${EASYTLS_PRINTF}" "%s\n%s\n" \
				"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
			[ $DISABLE_KILL_PPID ] || taskkill /F /PID ${EASYTLS_srv_pid}
		else
			[ $DISABLE_KILL_PPID ] || kill -15 ${EASYTLS_srv_pid}
		fi
	fi
	exit "${2:-255}"
}

# Tls-crypt-v2-verify failure, not an error.
fail_and_exit ()
{
	# Unlock
	release_lock "${easytls_lock_file}-stack" 6 || \
		update_status "v2-stack-fail_and_exit:release_lock-FAIL"
	release_lock "${easytls_lock_file}-v2" 5 || \
		update_status "v2-fail_and_exit:release_lock-FAIL"

	delete_metadata_files

	# shellcheck disable=SC2154
	if [ "${EASYTLS_VERBOSE}" ]
	then
		print "${status_msg}"
		print "${failure_msg}"
		print "${1}"
		print "* ==> version       local: ${local_easytls}"
		print "* ==> version      remote: ${md_easytls}"
		print "* ==> custom_group  local: ${local_custom_g}"
		print "* ==> custom_group remote: ${md_custom_g}"
		print "* ==> identity      local: ${local_identity}"
		print "* ==> identity     remote: ${md_identity}"
		print "* ==> X509 serial  remote: ${md_serial}"
		print "* ==> name         remote: ${md_name}"
		print "* ==> TLSK serial  remote: ${tlskey_serial}"
		print "* ==> sub-key      remote: ${md_subkey}"
		print "* ==> date         remote: ${md_date}"
		[ ${2} -eq 2 ] && print "* ==> Client serial status: revoked"
		[ ${2} -eq 3 ] && print "* ==> Client serial status: disabled"
		[ -n "${help_note}" ] && print "${help_note}"
	else
		print "${status_msg}"
		print "${failure_msg}"
		print "${1}"
	fi

	# TLSKEY connect log
	tlskey_status "*V!  FAIL" || update_status "tlskey_status FAIL"

	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s %s %s %s\n" \
		"<FAIL> ${status_msg}" "${failure_msg}" "${1}" \
			"kill_client: ${kill_client:-0}" > "${EASYTLS_WLOG}"

	[ $kill_client ] && {
		# Create kill client file
		"${EASYTLS_PRINTF}" "%s\n" "${md_serial}" > "${EASYTLS_KILL_FILE}"
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
	[ $keep_metadata ] || {
		"${EASYTLS_RM}" -f "${client_md_file}"
		update_status "temp-files deleted"
		}
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
		"${EASYTLS_GREP}" -c "^[[:blank:]]*Serial Number: ${md_serial}$"
}

# Final check: Search index.txt for Valid client cert serial number
fn_search_index ()
{
	"${EASYTLS_GREP}" -c \
		"^V.*[[:blank:]]${md_serial}[[:blank:]].*/CN=${md_name}.*$" \
		"${index_txt}"
}

# Check metadata client certificate serial number against CRL
serial_status_via_crl ()
{
	client_cert_revoked="$(fn_search_crl)"
	case $client_cert_revoked in
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
		die "Duplicate serial numbers: ${md_serial}" 127
		;;
		esac
	;;
	1)
		client_passed_x509_tests_certificate_revoked
	;;
	*)
		insert_msg="Duplicate serial numbers detected:"
		failure_msg="${insert_msg} ${md_serial}"
		die "Duplicate serial numbers: ${md_serial}" 128
	;;
	esac
}

# Check metadata client certificate serial number against CA
serial_status_via_ca ()
{
	# This is non-functional until OpenSSL is fixed
	verify_openssl_serial_status

	# Get serial status via CA
	client_cert_serno_status="$(openssl_serial_status)"

	# Format serial status
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
	# OpenSSL appears to always exit with error - but here I do not care
	"${EASYTLS_OPENSSL}" ca -cert "${ca_cert}" -config "${openssl_cnf}" \
		-status "${md_serial}" 2>&1
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
	"${EASYTLS_OPENSSL}" ca -cert "${ca_cert}" -config "${openssl_cnf}" \
		-status "${md_serial}" || \
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
	if [ $is_revoked -eq 0 ]
	then
		if [ $is_valid -eq 1 ]
		then
			client_passed_x509_tests
		else
			# Cert is not known
			insert_msg="Serial number is not in the CA database:"
			failure_msg="${insert_msg} ${md_serial}"
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
	"^V.*[[:blank:]]${md_serial}[[:blank:]].*\/CN=${md_name}.*$" \
		"${index_txt}"
}

# Final check: Search index.txt for Revoked client cert serial number
fn_search_revoked_pki_index ()
{
	"${EASYTLS_GREP}" -c \
	"^R.*[[:blank:]]${md_serial}[[:blank:]].*\/CN=${md_name}.*$" \
		"${index_txt}"
}

# This is the long way to connect - X509
client_passed_x509_tests ()
{
	insert_msg="Client certificate is recognised and Valid:"
	update_status "${insert_msg} ${md_serial}"
}

# This is the only way to fail for Revokation - X509
client_passed_x509_tests_certificate_revoked ()
{
	insert_msg="Client certificate is revoked:"
	failure_msg="${insert_msg} ${md_serial}"
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
	if [ $EASYTLS_FOR_WINDOWS ]
	then
		ping -n 1 127.0.0.1
	else
		sleep 1
	fi
}

# Simple lock file - Move this to a lib
acquire_lock ()
{
	[ -n "${1}" ] || return 1
	[ ${2} -gt 0 ] || return 1
	(
		lock_attempt=5
		set -o noclobber
		while [ ${lock_attempt} -gt 0 ]; do
			[ ${lock_attempt} -eq 5 ] || retry_pause
			lock_attempt=$(( lock_attempt - 1 ))
			case ${2} in
				1)	exec 1> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&1 || continue
					;;
				2)	exec 2> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&2 || continue
					;;
				3)	exec 3> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&3 || continue
					;;
				4)	exec 4> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&4 || continue
					;;
				5)	exec 5> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&5 || continue
					;;
				6)	exec 6> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&6 || continue
					;;
				7)	exec 7> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&7 || continue
					;;
				8)	exec 8> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&8 || continue
					;;
				9)	exec 9> "${1}" || continue
					"${EASYTLS_PRINTF}" "%s" "$$" >&9 || continue
					;;
				*) die "Invalid file descriptor" 191 ;;
			esac
			lock_acquired=1
			break
		done
		set +o noclobber
		[ $lock_acquired ] || return 1
	) || return 1
	update_status "acquire_lock"
}

release_lock ()
{
	[ -n "${1}" ] || return 1
	[ ${2} -gt 0 ] || return 1
		case ${2} in
		1) exec 1<&- || return 1; exec 1>&- || return 1 ;;
		2) exec 2<&- || return 1; exec 2>&- || return 1 ;;
		3) exec 3<&- || return 1; exec 3>&- || return 1 ;;
		4) exec 4<&- || return 1; exec 4>&- || return 1 ;;
		5) exec 5<&- || return 1; exec 5>&- || return 1 ;;
		6) exec 6<&- || return 1; exec 6>&- || return 1 ;;
		7) exec 7<&- || return 1; exec 7>&- || return 1 ;;
		8) exec 8<&- || return 1; exec 8>&- || return 1 ;;
		9) exec 9<&- || return 1; exec 9>&- || return 1 ;;
		*) die "Invalid file descriptor" 191 ;;
		esac
	"${EASYTLS_RM}" -f "${1}"
	update_status "release_lock"
}

# Write metadata file
write_metadata_file ()
{
	# Set the client_md_file
	client_md_file="${temp_stub}-tcv2-metadata-${tlskey_serial}"

	# Lock
	acquire_lock "${easytls_lock_file}-stack" 6 || \
		die "v2-stack:acquire_lock-FAIL" 99

	# Stack up duplicate metadata files or fail - vars ENABLE_STACK
	if [ -f "${client_md_file}" ]
	then
		stack_up || die "stack_up" 160
	fi

	if [ -f "${client_md_file}" ]
	then
		# If client_md_file still exists then fail
		tlskey_status "STALE_FILE_ERROR"
		keep_metadata=1
		fail_and_exit "STALE_FILE_ERROR" 101
	else
		# Otherwise stack-up
		"${EASYTLS_CP}" "${OPENVPN_METADATA_FILE}" "${client_md_file}" || \
			die "Failed to create client_md_file" 89
		update_status "Created client_md_file"
	fi
	# Lock
	release_lock "${easytls_lock_file}-stack" 6 || \
		die "v2-stack:release_lock" 99
} # => write_metadata_file ()

# Stack up
stack_up ()
{
	[ $stack_completed ] && die "STACK_UP CAN ONLY RUN ONCE" 161
	stack_completed=1

	i=1
	s=''

	# No Stack UP
	if [ ! $ENABLE_STACK ]
	then
		return 0
	fi

	# Full Stack UP
	while :
	do
		if [ -f "${client_md_file}_${i}" ]
		then
			s="${s}."
			i=$(( i + 1 ))
			continue
		else
			client_md_file="${client_md_file}_${i}"
			s="${s}${i}"
			break
		fi
	done
	update_status "stack-up"
	tlskey_status "  | => stack:+ ${s} -"
}

# TLSKEY tracking .. because ..
tlskey_status ()
{
	[ $EASYTLS_TLSKEY_STATUS ] || return 0
	{
		# shellcheck disable=SC2154
		"${EASYTLS_PRINTF}" '%s %s %s %s\n' "${local_date_ascii}" \
			"${tlskey_serial}" "*VF >${1}" "${md_name}"
	} >> "${EASYTLS_TK_XLOG}"
}

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# metadata version
	local_easytls='easytls'

	# Verify tlskey-serial number by hash of metadata
	VERIFY_hash=1

	# Do not accept external settings
	unset -v use_x509

	# TLS expiry age (days) Default 5 years, 1825 days
	tlskey_max_age=$((365*5))

	# Defaults
	EASYTLS_srv_pid=$PPID

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
	x509_method=0

	# Enable disable list by default
	use_disable_list=1

	# Identify Windows
	EASYRSA_KSH='@(#)MIRBSD KSH R39-w32-beta14 $Date: 2013/06/28 21:28:57 $'
	[ "${KSH_VERSION}" = "${EASYRSA_KSH}" ] && EASYTLS_FOR_WINDOWS=1

	# Required binaries
	EASYTLS_OPENSSL='openssl'
	EASYTLS_CAT='cat'
	EASYTLS_CP='cp'
	EASYTLS_DATE='date'
	EASYTLS_GREP='grep'
	EASYTLS_MV='mv'
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
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_CAT}.exe" ] || exit 65
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_CP}.exe" ] || exit 65
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_DATE}.exe" ] || exit 66
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_GREP}.exe" ] || exit 67
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

	# Lock file
	easytls_lock_file="${temp_stub}-lock"

	# Lock
	acquire_lock "${easytls_lock_file}-v2" 5 || \
		die "v2:acquire_lock-FAIL" 99

	# Windows log
	EASYTLS_WLOG="${temp_stub}-cryptv2-verify.log"
	EASYTLS_TK_XLOG="${temp_stub}-tcv2-ct.x-log"

	# Kill client file
	EASYTLS_KILL_FILE="${temp_stub}-kill-client"

	# HASH
	EASYTLS_HASH_ALGO="${EASYTLS_HASH_ALGO:-SHA256}"

	# CA_dir MUST be set with option: -c|--ca
	[ -d "${CA_dir}" ] || die "Path to CA directory is required, see help" 22

	# Easy-TLS required files
	TLS_dir="${CA_dir}/easytls/data"
	disabled_list="${TLS_dir}/easytls-disabled-list.txt"
	tlskey_serial_index="${TLS_dir}/easytls-key-index.txt"

	# Check TLS files
	[ -d "${TLS_dir}" ] || {
		help_note="Use './easytls init [no-ca]"
		die "Missing EasyTLS dir: ${TLS_dir}" 30
		}

	# CA required files
	ca_cert="${CA_dir}/ca.crt"
	ca_identity_file="${TLS_dir}/easytls-ca-identity.txt"
	crl_pem="${CA_dir}/crl.pem"
	index_txt="${CA_dir}/index.txt"
	openssl_cnf="${CA_dir}/safessl-easyrsa.cnf"

	# Check X509 files
	if [ $EASYTLS_NO_CA ]
	then
		# Do not need CA cert
		# Cannot do any X509 verification
		:
	else
		# Need CA cert
		[ -f "${ca_cert}" ] || {
			help_note="This script requires an EasyRSA generated CA."
			die "Missing CA certificate: ${ca_cert}" 23
			}

		if [ $use_cache_id ]
		then
			# This can soon be deprecated
			[ -f "${ca_identity_file}" ] || {
				help_note="This script requires an EasyTLS generated CA identity."
				die "Missing CA identity: ${ca_identity_file}" 33
				}
		fi

		# Check for either --cache-id or --preload-cache-id
		# Do NOT allow both
		[ $use_cache_id ] && [ $preload_cache_id ] && \
			die "Cannot use --cache-id and --preload-cache-id together." 34

		if [ $use_x509 ]
		then
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
	case "${tlskey_max_age}" in
		''|*[!0-9]*) # Invalid value
			die "Invalid value for --tls-age: ${tlskey_max_age}" 29
		;;
		*) # Valid value
			# maximum age in seconds
			tlskey_expire_age_sec=$((tlskey_max_age*60*60*24))
		;;
	esac

	# Source metadata lib
	prog_dir="${0%/*}"
	lib_file="${prog_dir}/easytls-metadata.lib"
	[ -f "${lib_file}" ] || {
		easytls_url="https://github.com/TinCanTech/easy-tls"
		easytls_rawurl="https://raw.githubusercontent.com/TinCanTech/easy-tls"
		easytls_file="/master/easytls-metadata.lib"
		easytls_wiki="/wiki/download-and-install"
		help_note="See: ${easytls_url}${easytls_wiki}"
		die "Missing ${lib_file} - Source: ${easytls_rawurl}${easytls_file}" 71
		}
	# shellcheck source=./easytls-metadata.lib
	. "${lib_file}"
	unset -v lib_file

	# Default CUSTOM_GROUP
	[ -n "${local_custom_g}" ] || local_custom_g='EASYTLS'

	# Need the date/time ..
	full_date="$("${EASYTLS_DATE}" '+%s %Y/%m/%d-%H:%M:%S')"
	local_date_ascii="${full_date##* }"
	local_date_sec="${full_date%% *}"

	# $metadata_file - Must be set by openvpn
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
while [ -n "${1}" ]
do
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
		vars_file="${val}"
	;;
	-c|--ca)
		CA_dir="${val}"
	;;
	-z|--no-ca)
		empty_ok=1
		EASYTLS_NO_CA=1
	;;
	-g|--custom-group)
		if [ -z "${local_custom_g}" ]
		then
			local_custom_g="${val}"
		else
			multi_custom_g=1
			local_custom_g="${val} ${local_custom_g}"
		fi
	;;
	-n|--no-hash)
		empty_ok=1
		unset -v VERIFY_hash
	;;
	-x|--max-tls-age)
		tlskey_max_age="${val}"
	;;
	-d|--disable-list)
		empty_ok=1
		unset -v use_disable_list
	;;
	-k|--kill-client) # Use client-connect to kill client
		empty_ok=1
		kill_client=1
	;;
	--hash)
		EASYTLS_HASH_ALGO="${val}"
	;;
	--v1|--via-crl)
		empty_ok=1
		update_status "(crl)"
		use_x509=1
		x509_method=1
	;;
	--v2|--via-ca)
		empty_ok=1
		update_status "(ca)"
		use_x509=1
		x509_method=2
	;;
	--v3|--via-index)
		empty_ok=1
		update_status "(index)"
		use_x509=1
		x509_method=3
	;;
	-a|--cache-id)
		empty_ok=1
		use_cache_id=1
	;;
	-p|--preload-id)
		preload_cache_id="${val}"
	;;
	-b|--base-dir)
		EASYTLS_base_dir="${val}"
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="${val}"
	;;
	-e|--easyrsa-bin-dir)
		EASYTLS_ersabin_dir="${val}"
	;;
	-o|--openvpn-bin-dir)
		EASYTLS_ovpnbin_dir="${val}"
	;;
	*)
		warn_die "Unknown option: ${1}"
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
if [ -f "${vars_file}" ]
then
	# shellcheck source=./easytls-cryptv2-verify.vars-example
	. "${vars_file}" || die "source failed: ${vars_file}" 77
	update_status "vars loaded"
else
	update_status "No vars loaded"
fi

# Dependancies
deps

# Write env file
[ $WRITE_ENV ] && {
	env_file="${temp_stub}-cryptv2-verify.env"
	if [ $EASYTLS_FOR_WINDOWS ]; then
		set > "${env_file}"
	else
		env > "${env_file}"
	fi
	unset -v env_file
	}

# Get metadata

	# Get metadata_string
	metadata_string="$("${EASYTLS_CAT}" "${OPENVPN_METADATA_FILE}")"
	[ -z "${metadata_string}" ] && die "failed to read metadata_file" 8

	# Populate metadata variables
	key_metadata_string_to_vars || die "key_metadata_string_to_vars" 87

	# Update log message
	update_status "CN: ${md_name}"

# Metadata version

	# metadata_version MUST equal 'easytls'
	case "${md_easytls}" in
	"${local_easytls}")
		update_status "${md_easytls} OK"
	;;
	'')
		failure_msg="metadata version is missing"
		fail_and_exit "METADATA_VERSION" 7
	;;
	*)
		failure_msg="metadata version is not recognised: ${md_easytls}"
		fail_and_exit "METADATA_VERSION" 7
	;;
	esac

# Metadata custom_group

	if [ $multi_custom_g ]
	then
		# This will do for the time being ..
		if "${EASYTLS_PRINTF}" "${local_custom_g}" | \
			"${EASYTLS_GREP}" -q "${md_custom_g}"
		then
			update_status "MULTI custom_group ${md_custom_g} OK"
		else
			failure_msg="multi_custom_g"
			fail_and_exit "MULTI_CUSTOM_GROUP" 98
		fi
	else
		# md_custom_g MUST equal local_custom_g
		case "${md_custom_g}" in
		"${local_custom_g}")
			update_status "custom_group ${md_custom_g} OK"
		;;
		'')
			failure_msg="metadata custom_group is missing"
			fail_and_exit "METADATA_CUSTOM_GROUP" 5
		;;
		*)
			failure_msg="metadata custom_group is not correct: ${md_custom_g}"
			fail_and_exit "METADATA_CUSTOM_GROUP" 5
		;;
		esac
	fi

# tlskey-serial checks

	if [ $VERIFY_hash ]
	then
		# Verify tlskey-serial is in index
		"${EASYTLS_GREP}" -q "${tlskey_serial}" "${tlskey_serial_index}" || {
			failure_msg="TLS-key is not recognised"
			fail_and_exit "TLSKEY_SERIAL_ALIEN" 10
			}

		# HASH metadata sring without the tlskey-serial
		# shellcheck disable=SC2154 # md_seed is referenced but not assigned
		md_hash="$("${EASYTLS_PRINTF}" '%s' "${md_seed}" | \
			"${EASYTLS_OPENSSL}" ${EASYTLS_HASH_ALGO} -r)"
		md_hash="${md_hash%% *}"
		[ "${md_hash}" = "${tlskey_serial}" ] || {
			failure_msg="TLS-key metadata hash is incorrect"
			fail_and_exit "TLSKEY_SERIAL_HASH" 11
			}

		update_status "tlskey-serial verified OK"
	else
		update_status "tlskey-serial verification disabled"
	fi

# tlskey expired

	# Verify key date and expire by --tls-age
	# Disable check if --tls-age=0 (Default age is 5 years)
	if [ "${tlskey_expire_age_sec}" -gt 0 ]
	then
		case "${local_date_sec}" in
		''|*[!0-9]*)
			# Invalid value - date.exe is missing
			die "Invalid value for local_date_sec: ${local_date_sec}" 112
		;;
		*) # Valid value
			tlskey_expire_age_sec=$((tlskey_max_age*60*60*24))

			# days since key creation
			tlskey_age_sec=$(( local_date_sec - md_date ))
			tlskey_age_day=$(( tlskey_age_sec / (60*60*24) ))

			# Check key_age is less than --tls-age
			if [ ${tlskey_age_sec} -gt ${tlskey_expire_age_sec} ]
			then
				max_age_msg="Max age: ${tlskey_max_age} days"
				key_age_msg="Key age: ${tlskey_age_day} days"
				failure_msg="Key expired: ${max_age_msg} ${key_age_msg}"
				fail_and_exit "TLSKEY_EXPIRED" 4
			fi

			# Success message
			update_status "Key age ${tlskey_age_day} days OK"
		;;
		esac
	fi

# Disabled list

	# Check serial number is not disabled
	# Use --disable-list to disable this check
	if [ $use_disable_list ]
	then
		[ -f "${disabled_list}" ] || \
			die "Missing disabled list: ${disabled_list}" 27

		# Search the disabled_list for client serial number
		if "${EASYTLS_GREP}" -q "^${tlskey_serial}[[:blank:]]" "${disabled_list}"
		then
			# Client is disabled
			failure_msg="TLS key serial number is disabled: ${tlskey_serial}"
			fail_and_exit "TLSKEY_DISABLED" 3
		else
			# Client is not disabled
			update_status "Enabled OK"
		fi
	fi


# Start opptional X509 checks
if [ ! $use_x509 ]
then
	# No X509 required
	update_status "metadata verified"
else

	# Verify CA cert is valid and/or set the CA identity
	if [ $use_cache_id ]
	then
		local_identity="$("${EASYTLS_CAT}" "${ca_identity_file}")"
	elif [ -n "${preload_cache_id}" ]
	then
		local_identity="${preload_cache_id}"
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
	if [ "${local_identity}" = "${md_identity}" ]
	then
		update_status "identity OK"
	else
		failure_msg="identity mismatch"
		fail_and_exit "IDENTITY MISMATCH" 6
	fi


	# Verify serial status
	case $x509_method in
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
		# reliably verify the 'OpenSSL ca $cmd'

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
		die "Unknown method for verify: ${x509_method}" 130
	;;
	esac

fi # => use_x509 ()

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
release_lock "${easytls_lock_file}-v2" 5 || die "v2:release_lock" 99

# There is only one way out of this...
if [ $absolute_fail -eq 0 ]
then
	# TLSKEY connect log
	tlskey_status ">>:    V-OK" || update_status "tlskey_status FAIL"

	# All is well
	verbose_print "${local_date_ascii} <EXOK> ${status_msg}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n" \
		"<EXOK> ${status_msg}" > "${EASYTLS_WLOG}"
	exit 0
fi

# Otherwise
fail_and_exit "ABSOLUTE FAIL" 9
