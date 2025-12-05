# Importing Self-Signed Root CA Certificates

This guide covers how to import a self-signed root CA certificate into the trust store of various operating systems.

## macOS

1. **Locate your certificate file** (e.g., `homelab-root-CA.crt` or `root-CA.pem`)

2. **Open a Terminal** and enter
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain homelab-root-CA.crt
```
Directly imrporting the certificate via Kechain Access did fail with an error `Error: -25294`. 

3. **Verfy it is imported** open the `Keychain Access` app and select `iCloud` or any other previosly selected key chain and search for the name of your certificate (in my case `Home Lab CA`). 

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

## Android

1. **Transfer your certificate** to your Android device (via USB, email, cloud storage, etc.)

2. **Open Settings** and navigate to **Security & privacy > More security settings > Encryption & credentials > Install a certificate**

3. **Select "CA certificate"** (note: this installs to the system trust store, though the exact location may vary)

4. **Choose "Install anyway"** if prompted about security risks

5. **Navigate to your certificate file** on your device and select it

6. **Name the certificate** when prompted (e.g., "My Root CA")

7. **Tap "OK"** to confirm

You can verify the certificate was installed in **Settings > Security & privacy > More security settings > Encryption & credentials > Trusted credentials > System**.

Note: On some devices, you may need developer mode enabled. Also, removing a system-installed certificate typically requires factory resetting the device.

## iOS

1. **Transfer your certificate** to your iOS device (email is the easiest method — attach the `.cer` or `.crt` file and open it on your device)

2. **Open the certificate** — iOS will display a dialog showing certificate details

3. **Tap "Install"** in the top right corner

4. **If prompted**, confirm installation by tapping "Install" again

5. **Enter your passcode** to authorize the installation

6. **Tap "Done"** to complete

7. **Enable the certificate** by going to **Settings > General > About > Certificate Trust Settings**

8. **Find your root CA certificate** in the list and toggle it **ON** (it will turn green)

The certificate is now fully trusted by iOS.

## Troubleshooting

**Certificate not trusted after import:**
- Ensure it's a root CA certificate, not an intermediate or end-entity certificate
- Verify the certificate file is in the correct format (`.crt`, `.cer`, or `.pem`)
- On Linux, restart services that use the CA bundle or reboot the system
- On browsers like Chrome, you may need to restart the browser after importing

**"Installation failed" on Android/iOS:**
- Try converting the certificate format: `openssl x509 -in root-ca.pem -out root-ca.crt`
- Ensure the certificate is valid and not expired
- Check that it's a self-signed root CA, not a signed certificate

**Permission denied on Linux:**
- Use `sudo` for all commands that modify system directories
- Ensure your user is in the appropriate groups if using alternative methods

## Verification Commands

To view certificate details before importing:
```bash
openssl x509 -in root-ca.crt -text -noout
```

To verify a certificate is self-signed:
```bash
openssl verify -CAfile root-ca.crt root-ca.crt
```