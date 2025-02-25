#!/bin/bash
# Use this script to enumerate logged in users, users with special permissions, and users needing changes. 


echo "========================================="
echo "  NCAE Cyber Games - User Security Audit"
echo "========================================="

# 1. Currently Logged-In Users
echo ""
echo "[INFO] Users currently logged in:"
who -u

# 2. Users with Shell Access
echo ""
echo "[INFO] Users that can execute commands:"
awk -F: '$NF ~ /sh$/ {print $1}' /etc/passwd

# 3. Users with Sudo/Root Access
echo ""
echo "[INFO] Users with sudo/root access:"
getent group sudo | cut -d: -f4

# 4. Users with No Password Set (High Security Risk)
echo ""
echo "[WARNING] Users with no password set (Fix immediately):"
awk -F: '($2=="") {print $1}' /etc/shadow 2>/dev/null

# 5. System Accounts Without Login Shells
echo ""
echo "[INFO] System accounts (non-login, typically safe):"
awk -F: '($NF ~ /nologin|false/) {print $1}' /etc/passwd

echo ""
echo "[INFO] User audit complete. Review and secure any unnecessary accounts."
