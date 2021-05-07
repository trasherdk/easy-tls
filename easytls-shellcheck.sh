#!/bin/sh

shellcheck_bin='shellcheck'
[ -f '../shellcheck' ] && shellcheck_bin='../shellcheck'

$shellcheck_bin --version
export SHELLCHECK_OPTS="-S warning"

printf '\n\n%s\n' '*** shellcheck easytls'
  $shellcheck_bin easytls && sc_easytls=$?
printf '\n\n%s\n' '*** shellcheck easytls-cryptv2-verify.sh'
  $shellcheck_bin easytls-cryptv2-verify.sh && sc_easytls_cryptv2_verify=$?
printf '\n\n%s\n' '*** shellcheck easytls-verify.sh'
  $shellcheck_bin easytls-verify.sh && sc_easytls_verify=$?
printf '\n\n%s\n' '*** shellcheck easytls-client-connect.sh'
  $shellcheck_bin easytls-client-connect.sh && sc_easytls_client_connect=$?

exit_status=$(( \
					sc_easytls + \
					sc_easytls_cryptv2_verify + \
					sc_easytls_verify + \
					sc_easytls_client_connect \
			 ))

[ $exit_status -eq 0 ] || echo "Easy-TLS Shellcheck exit status: $exit_status"