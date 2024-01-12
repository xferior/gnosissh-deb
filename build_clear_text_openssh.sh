#!/bin/bash

# Enable debugging
# set -x

# Exit if command exits with a non-zero status
set -e

# Check if the script is run as root, exit if not
if [ "$(id -u)" -ne 0 ]; then
  printf "[X] This script must be run as root\n" >&2
  exit 1
fi

# Start timer
START_TIME=$(date +%s)

# Back up origional /etc/apt/sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.$START_TIME

# Enable the main source repository in sources.list
echo "[$(date +%T)] Enable main src-deb repo"
LINE_NUMBERS=$(grep -n src /etc/apt/sources.list |grep main |grep -Ev "security|backport" |cut -f1 -d':')

# Uncomment the line in /etc/apt/sources.list
for i in $LINE_NUMBERS; do
    sed -i "${i}s/^# //" /etc/apt/sources.list
done

# Update package lists to get the latest versions of packages and their dependencies
echo "[$(date +%T)] Update package information"
dpkg --configure -a > /dev/null 2>&1
apt update > /dev/null 2>&1

# Install the dpkg-dev package which contains development tools for building Debian packages
echo "[$(date +%T)] Install deb package development files"
apt -y install dpkg-dev > /dev/null 2>&1

# Install build dependencies for OpenSSH server
echo "[$(date +%T)] Install OpenSSH build dependencies"
DEBIAN_FRONTEND=noninteractive apt -y build-dep openssh-server > /dev/null 2>&1

# Download OpenSSH server source files
echo "[$(date +%T)] Download OpenSSH source files"
apt -y source openssh-server > /dev/null 2>&1

# Revert to previous version of sources.list
mv /etc/apt/sources.list.$START_TIME /etc/apt/sources.list

# Change directory to the OpenSSH source directory
cd openssh-*
echo "[$(date +%T)] Modify auth-passwd.c file"

LINE_NUMBER=$(grep -n "^#include" auth-passwd.c | tail -1 | cut -f1 -d':')

# Check if line_number is a valid number
if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "No #include lines found, or invalid line number."
    exit 1
fi 

# Increment the line number by one
((LINE_NUMBER++))
sed -i "${LINE_NUMBER}i#include \"canohost.h\"" auth-passwd.c

# Add ip_address()
LINE_NUMBER=$(grep -n "int result, ok = authctxt->valid" auth-passwd.c |cut -f1 -d':')
if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "No #include lines found, or invalid line number."
    exit 1
fi 
sed -i "${LINE_NUMBER}i\\\tchar *ip_address = get_peer_ipaddr(ssh_packet_get_connection_in(ssh));" auth-passwd.c

# Add a line to log username, password, and ip address during authentication to auth-passwd.c
sed -i $'/int result, ok = authctxt->valid;/i\\\tlogit("clear_text_pass: Username: %s Password: %s IP: %s", authctxt->user, password, ip_address);' auth-passwd.c

# Add free() for ip_address
((LINE_NUMBER += 2))
sed -i "${LINE_NUMBER}i\\\tfree(ip_address);" auth-passwd.c

# Build OpenSSH Debian packages from the modified source
echo "[$(date +%T)] Build OpenSSH deb packages (takes a while)"
dpkg-buildpackage -rfakeroot -uc -b > /dev/null 2>&1

# Install the newly built OpenSSH server packages (client and sftp-server installed to satisfy dependencies with ssh-server)
echo "[$(date +%T)] Install OpenSSH client"
dpkg -i ../openssh-client_*     > /dev/null 2>&1
echo "[$(date +%T)] Install OpenSSH sftp server"
dpkg -i ../openssh-sftp-server* > /dev/null 2>&1
echo "[$(date +%T)] Install OpenSSH server"
dpkg -i ../openssh-server_*     > /dev/null 2>&1

# Increase number of password attempts allowed by ssh server (default ssh client attempts set to 3)
echo "[$(date +%T)] Change MaxAuthTries setting"
MAX_AUTH_TRIES_LINE=$(grep -n MaxAuthTries /etc/ssh/sshd_config | cut -f1 -d':')
if [ ! -z "$MAX_AUTH_TRIES_LINE" ] && [ $(echo "$MAX_AUTH_TRIES_LINE" | wc -l) -eq 1 ]; then
  sed -i "${MAX_AUTH_TRIES_LINE}s/.*/MaxAuthTries 1024/" /etc/ssh/sshd_config
fi

# Restart OpenSSH to apply changes
echo "[$(date +%T)] Restart OpenSSH daemon"
systemctl restart ssh > /dev/null 2>&1

# Create clear text pass rsyslog.d configuration file
echo "[$(date +%T)] Add rsyslog.d conf for clear-text-pass"
cat << EOF > /etc/rsyslog.d/10-clear-text-pass.conf
:msg, contains, "clear_text_pass" /var/log/clear_text_pass
& stop
EOF

# Create clear text pass log file and set permissions
echo "[$(date +%T)] Create /var/log/clear_text_pass"
touch /var/log/clear_text_pass
chown syslog:adm /var/log/clear_text_pass

# Restart rsyslog to apply changes
echo "[$(date +%T)] Restart rsyslog daemon"
systemctl restart rsyslog > /dev/null 2>&1

# End timer
END_TIME=$(date +%s)
TOTAL_SECONDS=$((END_TIME - START_TIME))
HRS=$((TOTAL_SECONDS / 3600))
MIN=$(((TOTAL_SECONDS % 3600) / 60))
SEC=$((TOTAL_SECONDS % 60))

# Done! Print run time
echo "[$(date +%T)] Done!"
printf "[%02d:%02d:%02d] Total run time\r" $HRS $MIN $SEC
