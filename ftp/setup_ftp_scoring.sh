#!/bin/bash
# setup_ftp_scoring.sh
#
# This script configures FTP on a Rocky Linux server (Rocky 8)
# to meet competition requirements:
# - FTP Scoring Directory: /mnt/files
# - Scoring users are ensured to exist with home directory (/home/$user) and a valid shell (/bin/bash)
#   and are added to the ftpusers group.
# - Users' password is set using the provided password hash.
# - vsftpd is installed and configured to allow local user logins via FTP,
#   chrooting them to /mnt/files regardless of their home directory.
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

# List of FTP scoring users (same as SSH users)
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
for user in "${FTP_USERS[@]}"; do
  # Check if user exists; if not, create with home directory /home/$user and shell /bin/bash.
  if id "$user" &>/dev/null; then
    echo "User $user exists; updating password and ensuring group membership."
    usermod -p "$PASSWORD_HASH" "$user"
    # Append the user to the ftpusers group if not already a member.
    usermod -a -G "$FTP_GROUP" "$user"
  else
    echo "Creating user $user with home directory /home/$user and shell /bin/bash"
    useradd -m -s /bin/bash "$user" -G "$FTP_GROUP" -p "$PASSWORD_HASH"
  fi
done

echo "Ensuring FTP directory $FTP_DIR exists..."
# Create the FTP scoring directory if it doesn't exist.
if [ ! -d "$FTP_DIR" ]; then
  mkdir -p "$FTP_DIR"
fi

# Set ownership and permissions for the FTP directory.
chown root:"$FTP_GROUP" "$FTP_DIR"
chmod 755 "$FTP_DIR"

echo "Backing up any existing vsftpd configuration..."
VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
if [ -f "$VSFTPD_CONF" ]; then
  cp "$VSFTPD_CONF" "${VSFTPD_CONF}.bak.$(date +%F-%T)"
fi

echo "Writing new vsftpd configuration..."
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
firewall-cmd --permanent --add-service=ftp
firewall-cmd --reload

echo "FTP configuration complete. Scoring users should now be able to log in via FTP."

