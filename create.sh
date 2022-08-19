#! /bin/bash
RED=$(printf '\033[1;31m')
YELLOW=$(printf '\033[1;33m')
GREEN=$(printf '\033[1;32m')
BOLD=$(printf '\033[1m')
NC=$(printf '\033[0m')         # No Color
DATE=$(date +%Y%m%d)
PRIME=prime256v1 
SSLDIR=/etc/ssl/private
WEBROOT=/var/www/html
VERBOSE=0

function usage() {
  printf "\nRenew an EC certificate\n\n"
  printf "Usage: %s -s 'SITE [SITE SITE ..]' [-o SSLDIR -p PRIME -w WEBROOT -h -v]\n\n" "$0"
  printf "  -s 'SITE SITE'  the site(s) to create a certificate for\n"
  printf "  -o SSLDIR       the certificate directory, default: '%s'\n" "${SSLDIR}"
  printf "  -p PRIME        the prime to use, default: '%s'\n" "${PRIME}"
  printf "  -w WEBROOT      the webroot directory, default: '%s'\n" "${WEBROOT}"
  printf "  -h              this help message\n"
  printf "  -v              be verbose\n\n"

  printf "Example:\n"
  printf "  %s -s 'one.example.com two.example.com three.example.com' -o /my/ssl/dir -w /var/www/one.example.com -p secp384r1 -v\n\n" "$0"
}

# Function: Exit with error.
function exit_abnormal() {
  usage 1>&2
  exit 1
}

function print_help() {
  usage
}

function init() {
  if (($# < 1)); then
    printf "  %s: Illegal number of parameters\n" "${RED}FAIL${NC}" >&2
    exit_abnormal
  fi
  while getopts :s:o:p:w:hv option; do
    case "${option}" in
    s) SITES=${OPTARG} ;;
    o) SSLDIR=${OPTARG};;
    p) PRIME=${OPTARG};;
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
  if [[ ! -d ${SSLDIR} ]]; then
    printf "%s: Certificate directory does not exist!" "${RED}FAIL${NC}" >&2
    exit 1
  fi
  SITE=$(awk '{print $1}' <(echo ${SITES}))
}

function create_dir() {
  if sudo test -d ${SSLDIR}/${SITE}; then
    if (( VERBOSE )); then
      printf "Certificate directory exists for '%s': %s\n" "${SITE}" "${SSLDIR}/${SITE}"
    fi
  else
    if (( VERBOSE )); then
      printf "Create directory for '%s': %s\n" "${SITE}" "${SSLDIR}/${SITE}"
    fi
    sudo mkdir ${SSLDIR}/${SITE}
  fi
}

function create_privkey_csr() {
  create_dir
  if (( VERBOSE )); then
    printf "Generate an EC private key\n"
  fi
  sudo openssl req -new -subj "/C=NL/ST=Gelderland/L=Doesburg/O=0x4.eu/OU=tech/CN=${SITE}" \
    -addext "subjectAltName = $(printf 'DNS:%s,' ${SITES}| sed 's/,$//')" \
    -addext "certificatePolicies = TLS Web Server Authentication, TLS Web Client Authentication" \
    -addext "basicConstraints = CA:FALSE" \
    -newkey ec -pkeyopt ec_paramgen_curve:${PRIME}\
    -keyout ${SSLDIR}/${SITE}/${DATE}_${SITE}.key.pem \
    -out ${SSLDIR}/${SITE}/${DATE}_${SITE}.csr.pem \
    -nodes -sha256 2>/dev/null
  if (( VERBOSE )); then
    printf " New private key: '%s'\n" "${SSLDIR}/${SITE}/${DATE}_${SITE}.key.pem"
    printf " CSR:             '%s'\n" "${SSLDIR}/${SITE}/${DATE}_${SITE}.csr.pem"
  fi
}


function symlink() {
  if (( VERBOSE )); then
    printf "Symlink private key and CSR\n"
  fi
  sudo ln -sf ${SSLDIR}/${SITE}/${DATE}_${SITE}.csr.pem /etc/ssl/private/${SITE}/csr.pem
  sudo ln -sf ${SSLDIR}/${SITE}/${DATE}_${SITE}.key.pem /etc/ssl/private/${SITE}/key.pem
}

function request_le_cert() {
  if (( VERBOSE )); then
    printf "Request a LE certificate\n"
  fi
  if sudo test -f ${SSLDIR}/${SITE}/csr.pem; then
    sudo certbot certonly --agree-tos --non-interactive \
      --webroot -w ${WEBROOT} \
      $(printf ' -d %s' ${SITES}) \
      --csr ${SSLDIR}/${SITE}/csr.pem \
      --cert-path ${SSLDIR}/${SITE}/privkey-ecdsa.pem \
      --chain-path ${SSLDIR}/${SITE}/chain-ecdsa.pem \
      --fullchain-path ${SSLDIR}/${SITE}/fullchain-ecdsa.pem
  else
    printf "file '${SSLDIR}/%s/csr.pem' does not exist, or is unreadable, aborting.\n" "${SITE}"
    exit_abnormal
  fi
}

# main program
init "$@"
create_privkey_csr
symlink
request_le_cert
