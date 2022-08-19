#! /bin/bash
RED=$(printf '\033[1;31m')
YELLOW=$(printf '\033[1;33m')
GREEN=$(printf '\033[1;32m')
BOLD=$(printf '\033[1m')
NC=$(printf '\033[0m')         # No Color
SSLDIR=/etc/ssl/private
WEBROOT=/var/www/html
VERBOSE=0

function usage() {
  printf "\nRenew an EC certificate\n\n"
  printf "Usage: %s -s SITE [-h -v]\n\n" "$0"
  printf "  -s SITE         the site to renew\n"
  printf "  -o SSLDIR       the certificate directory, default: '%s'\n" "${SSLDIR}"
  printf "  -w WEBROOT      the webroot, default: '%s'\n" "${WEBROOT}"
  printf "  -h              this help message\n"
  printf "  -v              be verbose\n\n"

  printf "Example:\n"
  printf "  %s -s site.example.com -o /my/ssl/dir -w /var/www/site.example.com\n\n" "$0"
}

# Function: Exit with error.
function exit_abnormal() {
  usage 1>&2
  exit 1
}

function print_help() {
  usage
  exit 0
}

function init() {
  if (($# < 1)); then
    printf "  %s: Illegal number of parameters\n" "${RED}FAIL${NC}" >&2
    exit_abnormal
  fi
  while getopts :s:o:w:hv option; do
    case "${option}" in
    s) SITE=${OPTARG} ;;
    o) SSLDIR=${OPTARG};;
    w) WEBROOT=${OPTARG};;
    h) print_help;;
    v) VERBOSE=1;;
    :)
      printf "%s\n" "${YELLOW}Fault:${NC} Option '-${OPTARG}' requires an argument"
      exit_abnormal
      ;;
    *)
      printf "%s\n" "${RED}Error:${NC} Unknown option"
      exit_abnormal
      ;;
    esac
  done
}

function request_le_cert() {
  if (( VERBOSE )); then
    printf "Request a LE certificate\n"
  fi
  if sudo test -f ${SSLDIR}/${SITE}/fullchain-ecdsa.pem; then
    SITES=$(printf '%s ' $(sudo cat ${SSLDIR}/${SITE}/fullchain-ecdsa.pem | openssl x509 -noout -ext subjectAltName | sed 1d | sed 's/DNS://g'))
    sudo certbot certonly --agree-tos --non-interactive \
      --webroot -w ${WEBROOT} \
      $(printf ' -d %s' ${SITES}) \
      --csr ${SSLDIR}/${SITE}/csr.pem \
      --cert-path ${SSLDIR}/${SITE}/privkey-ecdsa.pem \
      --chain-path ${SSLDIR}/${SITE}/chain-ecdsa.pem \
      --fullchain-path ${SSLDIR}/${SITE}/fullchain-ecdsa.pem
  else
    printf "%s: file '${SSLDIR}/%s/csr.pem' does not exist, or is unreadable, aborting.\n" "${RED}FAIL${NC}" "${SITE}" >&2
    exit_abnormal
  fi
}

# main program
init "$@"
request_le_cert
