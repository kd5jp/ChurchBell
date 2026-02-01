#!/bin/bash
# Clean up old SSL certificates and generate fresh ones

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/ssl"

echo "=== SSL Certificate Cleanup ==="
echo "Certificate directory: $CERT_DIR"
echo ""

# List existing certificate files
if [ -d "$CERT_DIR" ]; then
    echo "Existing certificate files:"
    ls -lah "$CERT_DIR"/*.pem "$CERT_DIR"/*.key "$CERT_DIR"/*.crt 2>/dev/null || echo "  (none found)"
    echo ""
    
    # Ask for confirmation
    read -p "Delete all existing SSL certificates? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing old certificates..."
        rm -f "$CERT_DIR"/*.pem "$CERT_DIR"/*.key "$CERT_DIR"/*.crt "$CERT_DIR"/*.csr 2>/dev/null || true
        echo "[OK] Old certificates removed"
        echo ""
        
        # Generate new certificates
        if [ -f "$SCRIPT_DIR/generate_ssl_cert.sh" ]; then
            echo "Generating new SSL certificates..."
            bash "$SCRIPT_DIR/generate_ssl_cert.sh"
            echo ""
            echo "=== Cleanup Complete ==="
            echo "Please restart the service:"
            echo "  sudo systemctl restart churchbell.service"
        else
            echo "[ERROR] generate_ssl_cert.sh not found"
            exit 1
        fi
    else
        echo "Cleanup cancelled."
        exit 0
    fi
else
    echo "SSL directory doesn't exist. Creating it..."
    mkdir -p "$CERT_DIR"
    bash "$SCRIPT_DIR/generate_ssl_cert.sh"
fi
