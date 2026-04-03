#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_CERT="$SCRIPT_DIR/homelab-root-CA.crt"
CA_KEY="$SCRIPT_DIR/homelab-ca-private_key.pem"
CA_SRL="$SCRIPT_DIR/homelab-root-CA.srl"

# --- Verify CA files exist ---
missing=0
[[ ! -f "$CA_CERT" ]] && { echo "Error: CA certificate not found: $CA_CERT"; missing=1; }
[[ ! -f "$CA_KEY"  ]] && { echo "Error: CA private key not found: $CA_KEY";  missing=1; }
[[ ! -f "$CA_SRL"  ]] && { echo "Error: CA serial file not found: $CA_SRL";  missing=1; }
(( missing )) && { echo "Run the bootstrap steps in CLAUDE.md to initialise the CA."; exit 1; }

echo "=== Homelab Certificate Generator ==="
echo ""

# --- Service name ---
read -rp "Service name (used for directory/file names, e.g. 'forgejo'): " SERVICE_NAME
SERVICE_NAME="${SERVICE_NAME,,}"  # lowercase

# --- Primary domain ---
read -rp "Primary domain (e.g. forgejo.grumples.home): " PRIMARY_DOMAIN

# --- Additional DNS names ---
EXTRA_DOMAINS=()
while true; do
    read -rp "Additional DNS name (leave blank to finish): " EXTRA
    [[ -z "$EXTRA" ]] && break
    EXTRA_DOMAINS+=("$EXTRA")
done

# --- IP addresses ---
IP_ADDRS=()
while true; do
    read -rp "IP address (leave blank to finish): " IP
    [[ -z "$IP" ]] && break
    IP_ADDRS+=("$IP")
done

# --- Cert details ---
read -rp "Organisational Unit (OU) [default: ${SERVICE_NAME^}]: " OU
OU="${OU:-${SERVICE_NAME^}}"

read -rp "Country (C) [default: US]: " COUNTRY
COUNTRY="${COUNTRY:-US}"

read -rp "State (ST) [default: New York]: " STATE
STATE="${STATE:-New York}"

read -rp "City (L) [default: New York]: " CITY
CITY="${CITY:-New York}"

# --- Validity ---
read -rp "Certificate validity in days [default: 398 Chrome requirement]: " DAYS
DAYS="${DAYS:-398}"

# --- Setup output dir ---
OUTPUT_DIR="$SCRIPT_DIR/$SERVICE_NAME"
if [[ -d "$OUTPUT_DIR" ]]; then
    read -rp "Directory '$OUTPUT_DIR' already exists. Overwrite? [y/N]: " OVERWRITE
    [[ "${OVERWRITE,,}" != "y" ]] && { echo "Aborted."; exit 1; }
fi
mkdir -p "$OUTPUT_DIR"

# --- Build alt_names block ---
ALT_NAMES="DNS.1 = $PRIMARY_DOMAIN"
DNS_IDX=2
for D in "${EXTRA_DOMAINS[@]}"; do
    ALT_NAMES+=$'\n'"DNS.$DNS_IDX = $D"
    DNS_IDX=$((DNS_IDX + 1))
done
IP_IDX=1
for IP in "${IP_ADDRS[@]}"; do
    ALT_NAMES+=$'\n'"IP.$IP_IDX = $IP"
    IP_IDX=$((IP_IDX + 1))
done

# --- Write .cnf ---
CNF="$OUTPUT_DIR/$SERVICE_NAME.cnf"
cat > "$CNF" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = distinguished_name

[distinguished_name]
C = $COUNTRY
ST = $STATE
L = $CITY
O = home lab
OU = $OU
CN = $PRIMARY_DOMAIN

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
$ALT_NAMES
EOF

echo ""
echo "Config written: $CNF"

# --- Generate private key ---
openssl genrsa -out "$OUTPUT_DIR/$SERVICE_NAME.key" 2048
echo "Private key:    $OUTPUT_DIR/$SERVICE_NAME.key"

# --- Generate CSR ---
openssl req -new \
    -key "$OUTPUT_DIR/$SERVICE_NAME.key" \
    -out "$OUTPUT_DIR/$SERVICE_NAME.csr" \
    -config "$CNF"
echo "CSR:            $OUTPUT_DIR/$SERVICE_NAME.csr"

# --- Sign with CA ---
echo ""
echo "Signing certificate — enter the CA key passphrase when prompted."
openssl x509 -req \
    -in "$OUTPUT_DIR/$SERVICE_NAME.csr" \
    -CA "$CA_CERT" \
    -CAkey "$CA_KEY" \
    -CAserial "$CA_SRL" \
    -out "$OUTPUT_DIR/$SERVICE_NAME.crt" \
    -days "$DAYS" \
    -sha256 \
    -extfile "$CNF" \
    -extensions v3_req

# --- Summary ---
echo ""
echo "=== Done ==="
echo ""
echo "  Config:      $OUTPUT_DIR/$SERVICE_NAME.cnf"
echo "  Private key: $OUTPUT_DIR/$SERVICE_NAME.key"
echo "  CSR:         $OUTPUT_DIR/$SERVICE_NAME.csr"
echo "  Certificate: $OUTPUT_DIR/$SERVICE_NAME.crt"
echo ""
echo "Verify:"
echo "  openssl x509 -in $OUTPUT_DIR/$SERVICE_NAME.crt -noout -text | grep -A2 'Subject Alternative'"
