#!/bin/bash
# Generate self-signed SSL certificate for HTTPS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/ssl"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"

echo "=== Generating SSL Certificate ==="
echo "Certificate directory: $CERT_DIR"
echo ""

# Create ssl directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Remove old certificates if they exist (to avoid conflicts)
if [ -f "$CERT_FILE" ] || [ -f "$KEY_FILE" ]; then
    echo "Removing old certificates..."
    rm -f "$CERT_FILE" "$KEY_FILE"
fi

# Get hostname/IP for certificate
HOSTNAME=$(hostname -f 2>/dev/null || hostname || echo "localhost")
IP_ADDRESS=$(hostname -I | awk '{print $1}' || echo "127.0.0.1")

echo "Generating self-signed certificate for:"
echo "  Hostname: $HOSTNAME"
echo "  IP: $IP_ADDRESS"
echo ""

# Generate self-signed certificate (valid for 10 years)
openssl req -x509 -newkey rsa:4096 -keyout "$KEY_FILE" -out "$CERT_FILE" \
    -days 3650 -nodes \
    -subj "/C=US/ST=State/L=City/O=ChurchBell/CN=$HOSTNAME" \
    -addext "subjectAltName=IP:$IP_ADDRESS,DNS:$HOSTNAME,DNS:localhost"

# Set proper permissions
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

echo ""
echo "=== SSL Certificate Generated ==="
echo "Certificate: $CERT_FILE"
echo "Private Key: $KEY_FILE"
echo ""
echo "Note: This is a self-signed certificate. Browsers will show a security warning."
echo "For production, consider using Let's Encrypt for trusted certificates."
echo ""
