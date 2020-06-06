#!/bin/sh

# Copyright - negotiable
copyright ()
{
cat << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# tls-crypt-v2-verify.sh -- Do simple magic
#
# Copyright (C) 2020 Richard Bonhomme (Friday 13th of March 2020)
# https://github.com/TinCanTech/easy-tls
# tincanteksup@gmail.com
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
#   disabled list
#   Identity (CA Fingerprint or "Identity")
#   Client certificate serial number against certificate revokation list
#   Or verify client certificate serial number status via `openssl ca`
#
VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
}

# This is here to catch "print" statements
# Wrapper around printf - clobber print since it's not POSIX anyway
# shellcheck disable=SC1117
print() { printf "%s\n" "$1"; }

# Exit on error
die ()
{
	[ -n "$help_note" ] && printf "\n%s\n" "$help_note"
	printf "\n%s\n" "ERROR: $1"
	printf "%s\n" "https://github.com/TinCanTech/easy-tls"
	exit "${2:-255}"
}

# Tls-crypt-v2-verify failure, not an error.
fail_and_exit ()
{
	if [ $TLS_CRYPT_V2_VERIFY_VERBOSE ]
	then
		printf "%s " "$tls_crypt_v2_verify_msg"
		[ -z "$success_msg" ] || printf "%s " "$success_msg"
		printf "%s\n%s\n" "$failure_msg $metadata_name" "$1"

		printf "%s\n" \
			"* ==> version       local: $local_version"

		printf "%s\n" \
			"* ==> version      remote: $metadata_version"

		[ $TLS_CRYPT_V2_VERIFY_CG ] && printf "%s\n" \
			"* ==> custom_group  local: $TLS_CRYPT_V2_VERIFY_CG"

		[ $TLS_CRYPT_V2_VERIFY_CG ] && printf "%s\n" \
			"* ==> custom_group remote: $metadata_custom_group"

		printf "%s\n" \
			"* ==> identity      local: $local_identity"

		printf "%s\n" \
			"* ==> identity     remote: $metadata_identity"

		printf "%s\n" \
			"* ==> serial       remote: $metadata_serial"

		printf "%s\n" \
			"* ==> name         remote: $metadata_name"

		printf "%s\n" \
			"* ==> date         remote: $metadata_date"

		[ $2 -eq 1 ] && printf "%s\n" \
			"* ==> Client serial status: revoked"

		[ -n "$help_note" ] && printf "%s\n" "$help_note"

		printf "%s\n" "https://github.com/TinCanTech/easy-tls"
	else
		printf "%s %s %s %s\n" "$tls_crypt_v2_verify_msg" \
			"$success_msg" "$failure_msg" "$metadata_name"
	fi
	exit "${2:-254}"
} # => fail_and_exit ()

# Help
help_text ()
{
	help_msg='
  tls-crypt-v2-verify.sh

  This script is intended to be used by tls-crypt-v2 client keys
  generated by EasyTLS.  See: https://github.com/TinCanTech/easy-tls

  Options:
  help|-h|--help      This help text.
  -v|--verbose        Be a little more verbose at run time (Not Windows).
  -c|--ca <path>      Path to CA *Required*
  -t|--tls-age        TLS Crypt V2 Key allowable age in days (default=1825).
                      To disable age check use --tls-age=0
  --verify-via-ca     Verify client serial number status via `openssl ca`
                      NOT RECOMMENDED
                      The recommended method to verify client serial number
                      status is via `openssl crl` (This is the Default).
  -g|--custom-group=<GROUP>
                      Also verify the client metadata against a custom group.
                      The custom group can be appended when EasyTLS generates
                      the tls-crypt-v2 client key by using:
                      easytls --custom-group=XYZ build-tls-crypt-v2-client
                      XYZ MUST be a single alphanumerical word with NO spaces.

  Exit codes:
  0   - Allow connection, Client key has passed all tests.
  1   - Disallow connection, client key has passed all tests but is REVOKED.
  2   - Disallow connection, serial number is disabled.
  3   - Disallow connection, local/remote Identities do not match.
  4   - Disallow connection, local/remote Custom Groups do not match.
  5   - Disallow connection, invalid metadata_version field.
  6   - Disallow connection, TLS key has expired.
  9   - BUG Disallow connection, general script failure.
  11  - ERROR Disallow connection, client key has invalid serial number.
  12  - ERROR Disallow connection, missing remote Identity.
  13  - ERROR Disallow connection, missing local Identity. (Unlucky)
  21  - USER ERROR Disallow connection, options error.
  22  - USER ERROR Disallow connection, failed to set --ca <path> *Required*.
  23  - USER ERROR Disallow connection, missing CA certificate.
  24  - USER ERROR Disallow connection, missing CRL file.
  25  - USER ERROR Disallow connection, missing index.txt.
  26  - USER ERROR Disallow connection, missing safessl-easyrsa.cnf.
  27  - USER ERROR Disallow connection, missing EasyTLS disabled list.
  28  - USER ERROR Disallow connection, missing openvpn server metadata_file.
  33  - USER ERROR Disallow connection, missing EasyTLS CA Identity file.
  121 - BUG Disallow connection, client serial number is not in CA database.
  122 - BUG Disallow connection, failed to verify CRL.
  123 - BUG Disallow connection, failed to verify CA.
  127 - BUG Disallow connection, duplicate serial number in CA database. !?
  253 - Disallow connection, exit code when --help is called.
  254 - BUG Disallow connection, fail_and_exit() exited with default error code.
  255 - BUG Disallow connection, die() exited with default error code.
'
	printf "%s\n" "$help_msg"

	# For secrity, --help must exit with an error
	exit 253
}

# Verify CA
verify_ca ()
{
	openssl x509 -in "$ca_cert" -noout
}

# Local identity
fn_local_identity ()
{
	if [ $TLS_CRYPT_V2_VERIFY_SECURE ]
	then
		printf "%s\n" "$ca_identity"

	else
		openssl x509 -in "$ca_cert" -noout -fingerprint | sed 's/ /_/g'
	fi
}

# Break metadata_string into variables
metadata_string_to_vars ()
{
	metadata_version="$1"
	metadata_identity="$2"
	metadata_serial="$3"
	metadata_name="$4"
	metadata_date="$5"
	metadata_custom_group="$6"
}

# Convert metadata file to metadata_string
metadata_file_to_metadata_string ()
{
	cat "$openvpn_metadata_file"
}

# Verify the age of the TLS key from metadata
verify_tls_key_date ()
{
	[ $tls_key_expire_age_seconds -eq 0 ] && return 0
	local_date=$(date +%s)
	expire_date=$((metadata_date + tls_key_expire_age_seconds))
	[ $local_date -lt $expire_date ] || return 1
}

# Requirements to verify a valid client cert serial number
verify_metadata_client_serial_number ()
{
	# Do we have a serial number
	[ -z "$metadata_serial" ] && {
		failure_msg="Missing: Client serial number"
		fail_and_exit "SERIAL_NUMBER_MISSING" 11
		}

	# Hex only accepted
	allow_hex_only || {
		failure_msg="Invalid: Client serial number"
		fail_and_exit "SERIAL_NUMBER_INVALID" 11
		}
}

# verify serial number is hex only
allow_hex_only ()
{
	printf '%s' "$metadata_serial" | grep -q '^[[:xdigit:]]\+$'
}

# Check metadata client certificate serial number against disabled list
verify_serial_number_not_disabled ()
{
	# Search the disabled_list for client serial number
	client_disabled="$(fn_search_disabled_list)"
	case $client_disabled in
	0)
		# Client is not disabled
		return 0
	;;
	*)
		# Client is disabled
		insert_msg="client serial number is disabled:"
		failure_msg="$insert_msg $metadata_serial"
		return 1
	;;
	esac

	# Otherwise fail
	help_note="Check your disabled list: $disabled_list"
	insert_msg="client serial number failed disabled test:"
	failure_msg="$insert_msg $metadata_serial"
	return 1
}

# Search disabled list for client serial number
fn_search_disabled_list ()
{
	grep -c "^${metadata_serial}[[:blank:]]${metadata_name}$" \
		"$disabled_list"
}

# Verify CRL
verify_crl ()
{
	openssl crl -in "$crl_pem" -noout
}

# Decode CRL
fn_read_crl ()
{
	openssl crl -in "$crl_pem" -noout -text
}

# Search CRL for client cert serial number
fn_search_crl ()
{
	printf "%s\n" "$crl_text" | grep -c \
		"^[[:blank:]]*Serial Number: ${metadata_serial}$"
}

# Final check: Search index.txt for Valid client cert serial number
fn_search_index ()
{
	grep -c "^V.*[[:blank:]]${metadata_serial}[[:blank:]].*$" \
		"$index_txt"
}

# Check metadata client certificate serial number against CRL
serial_status_via_crl ()
{
	client_cert_revoked="$(fn_search_crl)"
	case $client_cert_revoked in
	0)
		# Final check: Is this serial in index.txt
		case "$(fn_search_index)" in
		0)
		failure_msg="Serial number is not in the CA database:"
		fail_and_exit "SERIAL_NUMBER_UNKNOWN" 121
		;;
		1)
		client_passed_all_tests_connection_allowed
		;;
		*)
		die "Duplicate serial numbers: $metadata_serial" 127
		;;
		esac
	;;
	1)
		client_passed_all_tests_certificate_revoked
	;;
	*)
		insert_msg="Duplicate serial numbers detected: "
		failure_msg="$insert_msg $metadata_serial"
		die "Duplicate serial numbers: $metadata_serial" 127
	;;
	esac
}

# This is the only way to connect
client_passed_all_tests_connection_allowed ()
{
	insert_msg="Client certificate is recognised and not revoked:"
	success_msg="$success_msg $insert_msg $metadata_serial"
	success_msg="$success_msg $metadata_name"
	absolute_fail=0
}

# This is the only way to fail for Revokation
client_passed_all_tests_certificate_revoked ()
{
	insert_msg="Client certificate is revoked:"
	failure_msg="$insert_msg $metadata_serial"
	fail_and_exit "REVOKED" 1
}

# Check metadata client certificate serial number against CA
serial_status_via_ca ()
{
	# This is non-functional until openssl is fixed
	verify_openssl_serial_status

	# Get serial status via CA
	client_cert_serno_status="$(openssl_serial_status)"

	# Format serial status
	client_cert_serno_status="$(capture_serial_status)"
	client_cert_serno_status="${client_cert_serno_status% *}"
	client_cert_serno_status="${client_cert_serno_status##*=}"

	# Considering what has to be done, I don't like this
	case "$client_cert_serno_status" in
	Valid)
		client_passed_all_tests_connection_allowed
	;;
	Revoked)
		client_passed_all_tests_certificate_revoked
	;;
	*)
		die "Serial status via CA has broken" 9
	;;
	esac
}

# Use openssl to return certificate serial number status
openssl_serial_status ()
{
	# openssl appears to always exit with error - but here I do not care
	openssl ca -cert "$ca_cert" -config "$openssl_cnf" \
		-status "$metadata_serial" 2>&1
}

# Capture serial status
capture_serial_status ()
{
	printf "%s\n" "$client_cert_serno_status" | grep '^.*=.*$'
}

# Verify openssl serial status returns ok
verify_openssl_serial_status ()
{
	return 0 # Disable this `return` if you want to test
	# openssl appears to always exit with error - have not solved this
	openssl ca -cert "$ca_cert" -config "$openssl_cnf" \
		-status "$metadata_serial" || \
		die "openssl returned an error exit code" 101

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

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# metadata version
	local_version="metadata_version_easytls"

	# TLS expiry age (days) Default 5 years
	TLS_CRYPT_V2_VERIFY_TLS_AGE=$((365*5))

	# From openvpn server
	openvpn_metadata_file="$metadata_file"

	# Log message
	tls_crypt_v2_verify_msg="* TLS-crypt-v2-verify ==>"

	# Test certificate Valid/Revoked by CRL not CA
	test_method=1
}

# Dependancies
deps ()
{
	# CA_DIR MUST be set with option: -c|--ca
	[ -d "$CA_DIR" ] || die "Path to CA directory is required, see help" 22

	# CA required files
	ca_cert="$CA_DIR/ca.crt"
	ca_identity_file="$CA_DIR/easytls/easytls-ca-identity.txt"
	crl_pem="$CA_DIR/crl.pem"
	index_txt="$CA_DIR/index.txt"
	openssl_cnf="$CA_DIR/safessl-easyrsa.cnf"
	disabled_list="$CA_DIR/easytls/easytls-disabled.txt"

	# Ensure we have all the necessary files
	help_note="This script requires an EasyRSA generated CA."
	[ -f "$ca_cert" ] || die "Missing CA certificate: $ca_cert" 23

	if [ $TLS_CRYPT_V2_VERIFY_SECURE ]
	then
	help_note="This script requires an EasyTLS generated CA identity."
	[ -f "$ca_identity_file" ] || die "Missing CA identity: $ca_identity_file" 33
	ca_identity="$(cat "$ca_identity_file")"
	fi

	help_note="This script requires an EasyRSA generated CRL."
	[ -f "$crl_pem" ] || die "Missing CRL: $crl_pem" 24

	help_note="This script requires an EasyRSA generated DB."
	[ -f "$index_txt" ] || die "Missing index.txt: $index_txt" 25

	help_note="This script requires an EasyRSA generated PKI."
	[ -f "$openssl_cnf" ] || die "Missing openssl config: $openssl_cnf" 26

	help_note="This script requires an EasyTLS generated disabled_list."
	[ -f "$disabled_list" ] || \
		die "Missing disabled list: $disabled_list" 27

	# `metadata_file` must be set by openvpn
	help_note="This script can ONLY be used by a running openvpn server."
	[ -f "$openvpn_metadata_file" ] || \
		die "Missing: openvpn_metadata_file: $openvpn_metadata_file" 28
	unset help_note

	# Get metadata_string
	metadata_string="$(metadata_file_to_metadata_string)"

	# Populate metadata variables
	metadata_string_to_vars $metadata_string

	# Ensure that TLS expiry age is numeric
	[ $((TLS_CRYPT_V2_VERIFY_TLS_AGE)) -gt 0 ] || \
		TLS_CRYPT_V2_VERIFY_TLS_AGE=0

	# Calculate expite age in seconds
	tls_key_expire_age_seconds=$((TLS_CRYPT_V2_VERIFY_TLS_AGE*60*60*24))

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
		TLS_CRYPT_V2_VERIFY_VERBOSE=1
	;;
	-c|--ca)
		CA_DIR="$val"
	;;
	-t|--tls-age)
		TLS_CRYPT_V2_VERIFY_TLS_AGE="$val"
	;;
	--verify-via-ca)
		# This is only included for review
		empty_ok=1
		tls_crypt_v2_verify_msg="* TLS-crypt-v2-verify (ca) ==>"
		test_method=2
	;;
	-s|--secure)
		empty_ok=1
		TLS_CRYPT_V2_VERIFY_SECURE=1
	;;
	-g|--custom-group)
		TLS_CRYPT_V2_VERIFY_CG="$val"
	;;
	*)
		die "Unknown option: $1" 253
	;;
	esac

	# fatal error when no value was provided
	if [ ! $empty_ok ] && { [ "$val" = "$1" ] || [ -z "$val" ]; }; then
		die "Missing value to option: $opt" 21
	fi

	shift
done


# Dependancies
deps


# Metadata Version
	case $metadata_version in
	"$local_version")
		# metadata_version_easytls is correct
		success_msg="$metadata_version ==>"
	;;
	*)
		if [ -z "$metadata_version" ]
		then
			insert_msg="metadata version is missing."
		else
			insert_msg="metadata version is not recognised:"
		fi
		failure_msg="$insert_msg $metadata_version"
		fail_and_exit "METADATA_VERSION" 5
	;;
	esac


# Metadata custom_group
	if [ -n "$TLS_CRYPT_V2_VERIFY_CG" ]
	then
		if [ "$metadata_custom_group" = "$TLS_CRYPT_V2_VERIFY_CG" ]
		then
			# Custom group is correct
			insert_msg="custom_group $metadata_custom_group OK ==>"
			success_msg="$success_msg $insert_msg"
		else
			insert_msg="metadata custom_group is not correct:"
			[ -z "$metadata_custom_group" ] && \
				insert_msg="metadata custom_group is missing"

			failure_msg="$insert_msg $metadata_custom_group"
			fail_and_exit "METADATA_CUSTOM_GROUP" 4
		fi
	fi


# TLS Key expired

	# Verify key date and expire by --tls-age
	verify_tls_key_date || {
		failure_msg="TLS key has passed expiry age:"
		fail_and_exit "TLS_KEY_EXPIRED" 6
		}

# Client certificate serial number

	# Client serial number requirements
	verify_metadata_client_serial_number


# Disabled list check

	# Check serial number is not disabled
	verify_serial_number_not_disabled || fail_and_exit "CLIENT_DISABLED" 2


# Identity

	# Verify CA
	verify_ca || die "Bad CA $ca_cert" 123

	# Local Identity
	local_identity="$(fn_local_identity)"

	# local_identity is required
	[ -z "$local_identity" ] && {
		failure_msg="Missing: local identity"
		fail_and_exit "LOCAL_IDENTITY" 13
		}

	# metadata_identity is required
	[ -z "$metadata_identity" ] && {
		failure_msg="Missing: remote identity"
		fail_and_exit "REMOTE_IDENTITY" 12
		}


# Check metadata Identity against local Identity
if [ "$local_identity" = "$metadata_identity" ]
then
	insert_msg="identity OK ==>"
	success_msg="$success_msg $insert_msg"
else
	failure_msg="identity mismatch"
	fail_and_exit "IDENTITY_MISMATCH" 3
fi


# Certificate Revokation List

	# Verify CRL
	verify_crl || die "Bad CRL: $crl_pem" 122

	# Capture CRL
	crl_text="$(fn_read_crl)"


# Verify serial status by method 1 or 2

# Default test_method=1
test_method=${test_method:-1}

case $test_method in
	1)
		# Method 1
		# Check metadata client certificate serial number against CRL
		serial_status_via_crl
	;;
	2)
		# Method 2
		# Check metadata client certificate serial number against CA

		# Due to openssl being "what it is", it is not possible to
		# reliably verify the 'openssl ca $cmd'
		serial_status_via_ca
	;;
	*)
		die "Unknown method for verify: $test_method" 9
	;;
esac

# failure_msg means fail_and_exit
[ "$failure_msg" ] && fail_and_exit "NEIN" 9

# For DUBUG
[ "$FORCE_ABSOLUTE_FAIL" ] && absolute_fail=1 && \
	failure_msg="FORCE_ABSOLUTE_FAIL"

# There is only one way out of this...
[ $absolute_fail -eq 0 ] || fail_and_exit "ABSOLUTE_FAIL" 9

# All is well
[ $TLS_CRYPT_V2_VERIFY_VERBOSE ] && \
	printf "%s\n" "<EXOK> $tls_crypt_v2_verify_msg $success_msg"

exit 0
