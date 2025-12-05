# Create your own Root CA for signing Certificates for your home lab

## Install new OpenSSL on Mac

```bash
brew install openssl
```

## Generate a Private Key for your CA and enter pass phrase

```bash
openssl genrsa -aes256 -out homelab-ca-private_key.pem 2048
```

This command generates a 2048-bit RSA private key and saves it to a file called `homelab-ca-private_key.pem`.

- **`openssl genrsa`**: The OpenSSL command for generating RSA private keys.
- **`-aes256`**: Encrypts the private key using AES-256 encryption. When you run this command, you'll be prompted to enter a passphrase, which will be used to encrypt the key file. This means anyone who wants to use this key will need to enter the passphrase first, adding a layer of security. Without this flag, the key would be stored unencrypted and readable as plain text.
- **`-out homelab-ca-private_key.pem`**: Specifies the output filename where the encrypted key will be saved. The .pem extension stands for Privacy Enhanced Mail, which is a standard format for storing cryptographic keys.
- **`2048`**: The key size in bits. 2048 bits is the current standard for RSA keys and provides adequate security for most purposes. Larger key sizes (like 4096) offer more security but take longer to generate and use. Since this is for a homelab we are totally fine with 2048.
When you run this command, OpenSSL will ask you to enter and confirm a passphrase.

Keep this passphrase secure—you'll need it whenever you want to use this private key.

## Create a self-signed root Certificate Authority(CA) certificate

```bash
openssl req -x509 -new -nodes -key homelab-ca-private_key.pem  -sha256 -days 3650 -out homelab-root-CA.crt -subj "/CN=Home Lab CA"
```

**`openssl req`**
The `req` subcommand handles certificate signing requests (CSRs) and certificate generation.

**`-x509`**
Outputs a self-signed certificate instead of a certificate signing request. This makes it a root CA certificate that can sign other certificates.

**`-new`**
Generates a new certificate request. Combined with `-x509`, it creates a new certificate directly.

**`-nodes`**
"No DES" - stores the private key without encryption. The certificate won't be password-protected. Useful for automated processes nd homelab setups but less secure if the file is compromised.

**`-key homelab-ca-private_key.pem`**
Specifies the private key file to use. This is the key we created in the previous step with the `openssl genrsa` command.

**`-sha256`**
Uses SHA-256 as the message digest algorithm for signing. This is the current standard - older options like SHA-1 are deprecated.

**`-days 3650`**
Sets the certificate validity period to 3650 days (10 years). After this, the certificate expires and must be renewed.

**`-out homelab-root-CA.crt`**
Specifies the output file for the generated certificate.

**`-subj "/CN=Home Lab CA"`**
Sets the certificate's subject Distinguished Name (DN) directly on the command line, bypassing interactive prompts. `CN` is the Common Name - the human-readable name for this CA.

**The result:** You get `homelab-root-CA.crt`, a root CA certificate valid for 10 years that you can use to sign other certificates for local development or your homelab.

## Install the Root CA into Your System's Trust Store

## macOS

**Locate your certificate file** (e.g., `homelab-root-CA.crt` or `root-CA.pem`)

**Open a Terminal** and enter 

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain homelab-root-CA.crt
```

Directly importing the certificate via Kechain Access did fail with an error `Error: -25294`.

**Verfy it is imported** open the `Keychain Access` app and select `iCloud` or any other previosly selected key chain and search for the name of your certificate (in my case `Home Lab CA`).

## Linux

The process varies by distribution, but here are the most common approaches:

### Debian/Ubuntu

1. **Copy the certificate** to the trusted CA directory:

   ```bash
   sudo cp homelab-root-CA.crt /usr/local/share/ca-certificates/
   ```

2. **Update the CA store:**

   ```bash
   sudo update-ca-certificates
   ```

3. **Verify** it was added by checking:

   ```bash
   ls /etc/ssl/certs/ | grep root-ca
   ```

   ```

### General Verification

To verify the certificate is trusted by your system:

```bash
openssl verify -CAfile /etc/ssl/certs/ca-bundle.crt homelab-root-CA.crt
```

# generate self-signed certificate for 10 years

```bash
openssl req -x509 -sha256 -days 3650 -key private_key.pem -in server.csr -out server.pem
```

# validate the certificate

```bash
openssl req -in server.csr -text -noout | grep -i "Signature.*SHA256" && echo "All is well" || echo "This certificate doesn't work in 2017! You must update OpenSSL to generate a widely-compatible certificate"
```
