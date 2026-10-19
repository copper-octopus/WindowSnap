#!/bin/bash
# One-time setup: create a self-signed code-signing identity in the login keychain.
#
# An unsigned or ad-hoc-signed app is identified by its exact binary, so every rebuild
# looks like a new app and macOS drops its Accessibility permission. Signing with a
# fixed certificate pins the identity to the bundle ID plus this certificate instead.
# The certificate does not need to be trusted; codesign uses it either way.
set -e

NAME="WindowSnap Local Signing"

if security find-identity -p codesigning | grep -q "\"${NAME}\""; then
    echo "${NAME} already exists."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -subj "/CN=${NAME}" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning"

# -legacy: macOS's security tool cannot read OpenSSL 3's default PKCS#12 encryption.
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout pass:windowsnap -name "${NAME}"
security import "$TMP/id.p12" -k ~/Library/Keychains/login.keychain-db -P windowsnap -T /usr/bin/codesign

echo "Created ${NAME}. Rebuild, then grant Accessibility once more; later rebuilds keep it."
