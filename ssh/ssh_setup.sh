#!/bin/bash
# secure_ssh_keys.sh
#
# This script configures the SSH server on Rocky 8 to meet competition requirements:
# - It sets up each scoring user’s SSH environment so that public key authentication is enabled.
# - It writes the full scoring public key into each user’s authorized_keys file.
# - It hardens the SSH daemon configuration by disabling password and challenge-response authentication
#   and ensuring root login is disabled.
#
# Usage:
#   chmod +x secure_ssh_keys.sh
#   sudo ./secure_ssh_keys.sh

set -e

# Full scoring public key (DO NOT REMOVE)
SCORING_PUBKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcM4aDj8Y4COv+f8bd2WsrIynlbRGgDj2+q9aBeW1Umj5euxnO1vWsjfkpKnyE/ORsI6gkkME9ojAzNAPquWMh2YG+n11FB1iZl2S6yuZB7dkVQZSKpVYwRvZv2RnYDQdcVnX9oWMiGrBWEAi4jxcYykz8nunaO2SxjEwzuKdW8lnnh2BvOO9RkzmSXIIdPYgSf8bFFC7XFMfRrlMXlsxbG3u/NaFjirfvcXKexz06L6qYUzob8IBPsKGaRjO+vEdg6B4lH1lMk1JQ4GtGOJH6zePfB6Gf7rp31261VRfkpbpaDAznTzh7bgpq78E7SenatNbezLDaGq3Zra3j53u7XaSVipkW0S3YcXczhte2J9kvo6u6s094vrcQfB9YigH4KhXpCErFk08NkYAEJDdqFqXIjvzsro+2/EW1KKB9aNPSSM9EZzhYc+cBAl4+ohmEPej1m15vcpw3k+kpo1NC2rwEXIFxmvTme1A2oIZZBpgzUqfmvSPwLXF0EyfN9Lk= SCORING KEY DO NOT REMOVE"

# List of scoring SSH users
SCORING_USERS=(
  "camille_jenatzy"
  "gaston_chasseloup"
  "leon_serpollet"
  "william_vanderbilt"
  "henri_fournier"
  "maurice_augieres"
  "arthur_duray"
  "henry_ford"
  "louis_rigolly"
  "pierre_caters"
  "paul_baras"
  "victor_hemery"
  "fred_marriott"
  "lydston_hornsted"
  "kenelm_guinness"
  "rene_thomas"
  "ernest_eldridge"
  "malcolm_campbell"
  "ray_keech"
  "john_cobb"
  "dorothy_levitt"
  "paula_murphy"
  "betty_skelton"
  "rachel_kushner"
  "kitty_oneil"
  "jessi_combs"
  "andy_green"
)

echo "Configuring scoring users for SSH public key authentication..."
for user in "${SCORING_USERS[@]}"; do
  USER_HOME="/home/$user"
  SSH_DIR="$USER_HOME/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"
  
  # Ensure the user exists
  if id "$user" &>/dev/null; then
    echo "Setting up SSH for user: $user"
    # Create .ssh directory if it does not exist
    if [ ! -d "$SSH_DIR" ]; then
      mkdir -p "$SSH_DIR"
      chown "$user:$user" "$SSH_DIR"
      chmod 700 "$SSH_DIR"
      echo "Created $SSH_DIR"
    fi
    
    # Write the full scoring public key into authorized_keys (overwriting any existing keys)
    echo "$SCORING_PUBKEY" > "$AUTH_KEYS"
    chown "$user:$user" "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    echo "Configured $AUTH_KEYS with the scoring public key for $user"
  else
    echo "User $user does not exist. Skipping..."
  fi
done

echo "Updating SSH daemon configuration..."

SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
  cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%F-%T)"
fi

# Update or add required settings in /etc/ssh/sshd_config:
#   - Disable root login.
#   - Disable password and challenge-response authentication.
#   - Ensure public key authentication is enabled.
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
# Optionally disable PAM if required by competition instructions
sed -i 's/^#\?UsePAM.*/UsePAM no/' "$SSHD_CONFIG"

# (Optional) Configure ListenAddress if needed.
# Example: sed -i 's/^#\?ListenAddress.*/ListenAddress 0.0.0.0/' "$SSHD_CONFIG"

# Ensure drop-in configuration to disable root login
DISABLE_ROOT_CONF="/etc/ssh/sshd_config.d/disable_root_login.conf"
if [ ! -f "$DISABLE_ROOT_CONF" ]; then
  echo "Creating drop-in config $DISABLE_ROOT_CONF..."
  echo "PermitRootLogin no" > "$DISABLE_ROOT_CONF"
else
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$DISABLE_ROOT_CONF"
fi

echo "Restarting SSH service..."
systemctl restart sshd

echo "SSH configuration complete. Scoring users should now be able to log in using public key authentication."
