#!/bin/bash



# Variables
USERNAME="ubuntu"
PASSWORD="AnSiBl#&8B#@"

# Create user if it doesn't exist
if id "$USERNAME" &>/dev/null; then
echo "$USERNAME:$PASSWORD" | chpasswd
    echo "User $USERNAME already exists."
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "User $USERNAME created and password set."
fi

# Add user to sudo group (optional)
usermod -aG sudo "$USERNAME"
echo "ubuntu ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

mkdir -p /home/ubuntu/.ssh
chown ubuntu:ubuntu /home/ubuntu/.ssh

chmod 700 /home/ubuntu/.ssh
touch /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Disable password authentication and enable key-based authentication
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

