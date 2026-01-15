# Secret Management with Sops-Nix

This project uses [sops-nix](https://github.com/Mic92/sops-nix) to manage secrets. Secrets are encrypted with **Age** and stored in `secret/secrets.yaml`.

## Prerequisites

To decrypt or edit secrets, you must have the **Admin Age Key** on your machine.
- **Location:** `~/.config/sops/age/keys.txt`
- **Environment Variable:** `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`

## Managing Secrets

### 1. Editing the File (Interactive)
The easiest way to view or edit secrets is to open the file in your default editor ($EDITOR). Sops handles the decryption/encryption automatically.

```bash
sops secret/secrets.yaml
```

### 2. Adding or Updating a Secret (Command Line)
You can set a key-value pair directly without opening the editor.

```bash
# Set a value (creates it if missing)
sops --set '["my_secret_key"] "my_secret_value"' secret/secrets.yaml

# Example with nested keys
sops --set '["api_keys"]["github"] "ghp_12345..."' secret/secrets.yaml
```

### 3. Deleting a Secret
Open the file interactively and delete the lines:
```bash
sops secret/secrets.yaml
```

### 4. Renaming a Secret
Renaming is a two-step process in the editor:
1. Copy the value to a new key.
2. Delete the old key.

## Managing Keys & Hosts

The configuration file `.sops.yaml` defines which keys can decrypt the secrets.

### Adding a New Host
1. **Get the Host Key:**
   On the new server, get the SSH host key fingerprint converted to Age format.
   ```bash
   # On the server or via SSH
   ssh-keyscan -t ed25519 <hostname> | ssh-to-age
   # OR if you have the public key string
   echo "ssh-ed25519 AAA..." | ssh-to-age
   ```

2. **Update Config:**
   Add the new Age fingerprint to `.sops.yaml` under `keys`.
   ```yaml
   keys:
     - &host_new_server age1...
   creation_rules:
     - key_groups:
       - age:
         - *host_new_server
   ```

3. **Re-encrypt the File:**
   You must update the secrets file to encrypt it for the new key.
   ```bash
   sops updatekeys secret/secrets.yaml
   ```

4. **Commit & Push:**
   Commit both `.sops.yaml` and `secret/secrets.yaml`.

## Troubleshooting
**"Error getting data key: 0 successful groups required, got 0"**
- Ensure your `SOPS_AGE_KEY_FILE` env var is set correctly.
- Ensure the host's key in `.sops.yaml` matches exactly what is on the server (check with `ssh-to-age`).
- Run `sops updatekeys secret/secrets.yaml` to ensure all recipients are up to date.
