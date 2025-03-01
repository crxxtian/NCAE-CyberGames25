#!/bin/bash
# setup_ssh_scoring.sh
#
# This script configures SSH for scoring users to use public key authentication.
# It ensures each scoring user exists with a home directory (/home/$user) and a valid shell (/bin/bash),
# then it sets up their ~/.ssh/authorized_keys with the provided scoring public key.
#
# Usage:
#   chmod +x setup_ssh_scoring.sh
#   sudo ./setup_ssh_scoring.sh

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
  # Check if user exists; if not, create with home directory /home/$user and shell /bin/bash.
  if id "$user" &>/dev/null; then
    echo "User $user exists."
  else
    echo "Creating user $user with home directory /home/$user and shell /bin/bash"
    useradd -m -s /bin/bash "$user"
  fi

  USER_HOME=$(getent passwd "$user" | cut -d: -f6)
  SSH_DIR="$USER_HOME/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"
  
  # Create .ssh directory if it doesn't exist.
  if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chown "$user:$user" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    echo "Created $SSH_DIR for $user"
  fi
  
  # Write the scoring public key into authorized_keys (overwriting any existing keys).
  echo "$SCORING_PUBKEY" > "$AUTH_KEYS"
  chown "$user:$user" "$AUTH_KEYS"
  chmod 600 "$AUTH_KEYS"
  echo "Configured $AUTH_KEYS for $user"
done

echo "SSH configuration for scoring users complete."

