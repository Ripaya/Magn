#!/usr/bin/env bash
set -euo pipefail

KEYSTORE_PATH="${1:-android/app/magn-alpha.jks}"
KEY_ALIAS="${2:-magn-alpha}"

if [ -f "$KEYSTORE_PATH" ]; then
  echo "Keystore already exists at: $KEYSTORE_PATH"
  echo "Delete or pass a different path if you intentionally want a new key."
  exit 1
fi

read -rsp "Enter keystore password (min 6 chars): " STORE_PASS
echo ""
read -rsp "Enter key password (press Enter to reuse keystore password): " KEY_PASS
echo ""
if [ -z "$KEY_PASS" ]; then
  KEY_PASS="$STORE_PASS"
fi

keytool -genkeypair -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=Magn, OU=Mobile, O=Magn, L=Unknown, S=Unknown, C=US"

cat > android/key.properties <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=magn-alpha.jks
EOF

echo ""
echo "Created $KEYSTORE_PATH and android/key.properties (both gitignored)."
echo "Add these 4 GitHub Repository Secrets for consistent alpha signing:"
echo "  ANDROID_KEY_ALIAS:    $KEY_ALIAS"
echo "  ANDROID_KEYSTORE_PASSWORD: <your store password>"
echo "  ANDROID_KEY_PASSWORD: <your key password>"
echo "  ANDROID_KEYSTORE_BASE64:"
if base64 --help 2>&1 | grep -q -- "-w"; then
  base64 -w 0 "$KEYSTORE_PATH"
else
  base64 -i "$KEYSTORE_PATH" | tr -d '\n'
fi
echo ""
