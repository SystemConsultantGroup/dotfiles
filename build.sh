#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
AGE_KEY="${HOME}/.config/age/keys.txt"

# --- re-encrypt secrets from local state into the repo ---

if [ -f "$AGE_KEY" ]; then
  AGE()   { nix shell nixpkgs#age --command age       "$@"; }
  AGEKG() { nix shell nixpkgs#age --command age-keygen "$@"; }
  PUBKEY=$(AGEKG -y "$AGE_KEY")

  AUTH_SRC="${HOME}/.local/share/opencode/auth.json"
  AUTH_DST="${REPO_DIR}/secrets/opencode.age"

  if [ -f "$AUTH_SRC" ]; then
    AGE -a -r "$PUBKEY" < "$AUTH_SRC" > "$AUTH_DST"
    echo "re-encrypted ${AUTH_SRC} -> ${AUTH_DST}"
  fi
else
  echo "no age key at ${AGE_KEY} -- skipping re-encrypt"
fi

# --- build ---

nh os build "$REPO_DIR"
