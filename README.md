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

### macOS

**Locate your certificate file** (e.g., `homelab-root-CA.crt` or `root-CA.pem`)

**Open a Terminal** and enter 

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain homelab-root-CA.crt
```

Directly importing the certificate via Kechain Access did fail with an error `Error: -25294`.

**Verfy it is imported** open the `Keychain Access` app and select `iCloud` or any other previosly selected key chain and search for the name of your certificate (in my case `Home Lab CA`).

### Linux

The process varies by distribution, but here are the most common approaches:

#### Debian/Ubuntu

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

#### General Verification

To verify the certificate is trusted by your system:

```bash
openssl verify -CAfile /etc/ssl/certs/ca-bundle.crt homelab-root-CA.crt
```

## Generate a Server Certificate

As an example we are going to create a server certificate for proxmox.

### 1. Generate a private key on the server

SSH or MOSH into your proxmox server. Execute the following command

```bash
openssl genrsa -out proxmox.key 2048
```

Like for the root CA setup, this creates a key for the server.

### 2. Create an OpenSSL configuration file

Create an OpenSSL configuration file (in our example `proxmox.cnf`) to ensure the certificate includes the Subject Alternative Names (SANs) for both the IP and FQDN. This is essential for modern browsers to trust the certificate.
Create the file `proxmox.cnf` and add the following content:

```bash
[req]
# RSA key size to 2048 bits
default_bits = 2048
# Disables interactive prompts. OpenSSL will use values from the config file instead of asking you to enter them manually.
prompt = no 
#Specifies SHA-256 as the default message digest (hashing algorithm) for signing operations. 
default_md = sha256
#points to the section [distinguished_name] below that contains the subject information for the certificate.
distinguished_name = distinguished_name

#fill these out with your own settings
[distinguished_name]
C = US
ST = New York
L = New York
O = home lab #Organization name (company/entity).
OU = Proxmox    #Organizational Unit (department/divisio
#Common Name - the most important field. This should match the hostname or domain name that clients will use to connect. Here it's pve.local for a Proxmox Virtual Environment server. Must be less than 64 Char.
CN = *.proxmox.homelab.home, 192.168.1.10 

#X.509 v3 extensions that define how the certificate can be used
[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
#Specifies the certificate is intended for server authentication (TLS/SSL servers). This is required for HTTPS servers.
extendedKeyUsage = serverAuth 
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.proxmox.homelab.home
IP.1 = 192.168.1.10
```

## 3. Generate the Certificate Signing Request (CSR)
    
With the previously created key and cnf file.

```bash
openssl req -new -key proxmox.key -out proxmox.csr -config proxmox.cnf
```

## 4. Copy the CSR

Copy the `proxmox.csr` and `proxmox.cnf` file from the Proxmox server to the machine where you stored your Root CA keys (e.g., via scp or a shared drive). Keep the proxmox.key file secure on the Proxmox server.

## 5. Sign the CSR with Your Root CA

On the machine where the root CA is located and where you just copied the csr/cnf to sign the CSR with our Root CA's private key and certificate:

```bash
openssl x509 -req -in proxmox.csr -CA homelab-root-CA.crt -CAkey homelab-ca-private_key.pem -CAcreateserial -out proxmox.crt -days 365 -sha256 -extfile proxmox.cnf -extensions v3_req

```
This OpenSSL command **signs a certificate signing request (CSR) using your Root CA** to create a server certificate. Here's what each part does:

**Basic Command Structure**

**`openssl x509`**
The X.509 certificate utility for displaying and signing certificates.

**`-req`**
Indicates the input file is a certificate signing request (CSR), not an existing certificate.

**`-in proxmox.csr`**
The input CSR file containing the certificate request for your Proxmox server (includes public key and subject information).

**CA Signing Parameters**

**`-CA homelab-root-CA.crt`**
Specifies your Root CA certificate file that will be used to sign this certificate. This establishes the trust chain.

**`-CAkey homelab-ca-private_key.pem`**
The Root CA's private key used to cryptographically sign the new certificate. This proves the CA vouches for this certificate.

**`-CAcreateserial`**
Automatically creates and manages a serial number file (homelab-root-CA.srl) if it doesn't exist. Each certificate signed by a CA needs a unique serial number for tracking and revocation.

**Output Parameters**

**`-out proxmox.crt`**
The output file where the signed certificate will be written. This is your final Proxmox server certificate.

**`-days 365`**
Sets the certificate validity period to 3650 days (10 years). After this, the certificate expires and needs renewal.

**`-sha256`**
Uses SHA-256 as the hashing algorithm for the signature. This is the secure standard (SHA-1 is deprecated).

**Extensions**

**`-extfile proxmox.cnf`**
Specifies an external configuration file containing X.509 v3 extensions (like your keyUsage, extendedKeyUsage, and subjectAltName settings).
By default, the openssl x509 command (acting as a mini-CA) does not copy extensions from the CSR to the final certificate, that's why we need the same config (or a different) for final cert. All other fields in the config will be used from the CSR.

**`-extensions v3_req`**
Tells OpenSSL which section from the config file to use for extensions. This references the `[v3_req]` section in your proxmox.cnf file.

The resulting `proxmox.crt` can now be installed on your Proxmox server, and any client that trusts your `homelab-root-CA.crt` will trust this certificate.

**Verify the certificate content**
In particular the SAN entries.

```bash
openssl x509 -in proxmox.crt -text -noout | grep "Subject Alternative Name" -A 1
```
