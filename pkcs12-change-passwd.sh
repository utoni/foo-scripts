#!/usr/bin/env bash

set -e
set -x

IN_PKCS12="${1}"
IN_PASSWD="${2}"

test "INPUT PKCS12: ${IN_PKCS12}" != "INPUT PKCS12: "
test "INPUT PASSWD: ${IN_PASSWD}" != "INPUT PASSWD: "

openssl pkcs12 -clcerts -nokeys -in "${IN_PKCS12}" \
    -out certificate.crt -password "pass:${IN_PASSWD}" -passin "pass:${IN_PASSWD}"

openssl pkcs12 -cacerts -nokeys -in "${IN_PKCS12}" \
    -out ca-cert.ca -password "pass:${IN_PASSWD}" -passin "pass:${IN_PASSWD}"

openssl pkcs12 -nocerts -in "${IN_PKCS12}" \
    -out private.key -password "pass:${IN_PASSWD}" -passin "pass:${IN_PASSWD}" \
    -passout pass:TemporaryPassword

openssl rsa -in private.key -out "NewKeyFile.key" \
    -passin pass:TemporaryPassword

cat "NewKeyFile.key"  \
    "certificate.crt" \
    "ca-cert.ca" > PEM.pem

openssl pkcs12 -export -nodes -CAfile ca-cert.ca \
    -in PEM.pem -out "NewKeyFile.pfx"
