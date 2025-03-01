#!/bin/bash
# setup_ftp_scoring.sh
#
# This script configures FTP on a Rocky Linux server (Rocky 8/9)
# to meet the competition requirements:
# - FTP Scoring Directory: /mnt/files
# - FTP Scoring Users (listed below) are created with the provided password hash.
# - vsftpd is installed and configured to allow local user logins via FTP.
#
# Usage:
#   chmod +x setup_ftp_scoring.sh
#   sudo ./setup_ftp_scoring.sh

set -e

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

echo "Checking for required packages..."
# Check and install vsftpd if not installed.
if ! rpm -q vsftpd &>/dev/null; then
  echo "vsftpd not found. Installing..."
  yum install -y vsftpd
else
  echo "vsftpd is already installed."
fi

# Variables
FTP_DIR="/mnt/files"
FTP_GROUP="ftpusers"
# Password hash for FTP scoring users
PASSWORD_HASH='$6$KHk2hJlrIZKWxWA9$z2OrpVg05wxoUp/BL12VY9rvxvgyZhta.qKf9SwckeNMcW4QvCJACSA4QyBwy88UpPAGDrskbu7rb7sh8fbnM1'

# List of FTP scoring users
FTP_USERS=(
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

echo "Setting up group ${FTP_GROUP}..."
# Create the dedicated FTP group if it doesn't exist.
if ! getent group "$FTP_GROUP" > /dev/null; then
  groupadd "$FTP_GROUP"
fi

echo "Creating/updating FTP scoring users..."
# Create FTP scoring users or update them if they already exist.
for user in "${FTP_USERS[@]}"; do
  if id "$user" &>/dev/null; then
    echo "User $user exists; updating password and group membership."
    usermod -p "$PASSWORD_HASH" "$user"
    usermod -a -G "$FTP_GROUP" "$user"
  else
    echo "Creating user $user..."
    # Set home directory to FTP_DIR and disable shell access.
    useradd -m -d "$FTP_DIR" -s /sbin/nologin -g "$FTP_GROUP" -p "$PASSWORD_HASH" "$user"
  fi
done

echo "Ensuring FTP directory $FTP_DIR exists..."
# Create the FTP scoring directory if it doesn't exist.
if [ ! -d "$FTP_DIR" ]; then
  mkdir -p "$FTP_DIR"
fi

# Set ownership and permissions.
# For chrooted FTP, the home directory should be owned by root and not writable by the user.
chown root:"$FTP_GROUP" "$FTP_DIR"
chmod 755 "$FTP_DIR"

echo "Backing up any existing vsftpd configuration..."
VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
if [ -f "$VSFTPD_CONF" ]; then
  cp "$VSFTPD_CONF" "${VSFTPD_CONF}.bak.$(date +%F-%T)"
fi

echo "Writing new vsftpd configuration..."
# Configure vsftpd securely for local users.
cat > "$VSFTPD_CONF" <<EOF
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=NO
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
user_sub_token=\$USER
local_root=$FTP_DIR
EOF

echo "Enabling and restarting vsftpd service..."
systemctl enable vsftpd
systemctl restart vsftpd

echo "Configuring firewall for FTP access..."
# Open FTP service in the firewall.
firewall-cmd --permanent --add-service=ftp
firewall-cmd --reload

echo "FTP configuration complete."
echo "Scoring users should now be able to log in via FTP."
