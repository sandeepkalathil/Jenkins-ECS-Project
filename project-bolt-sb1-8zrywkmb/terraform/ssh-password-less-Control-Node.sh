#!/bin/bash

apt-get install -y sshpass

PASSWORD="AnSiBl#&8B#@"

# Generate SSH key pair for ubuntu if it doesn't exist
if [ ! -f /home/ubuntu/.ssh/id_rsa ]; then
    sudo -u ubuntu ssh-keygen -t rsa -b 4096 -f /home/ubuntu/.ssh/id_rsa -N ""
fi

# Add the public key to authorized_keys for ubuntu
cat /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys

# Prompt user for instance IPs
read -p "Enter Worker Node 1 IP: " WORKER1_IP

# Define an array with instance IPs
INSTANCE_IPS="$WORKER1_IP"

# Loop through each instance IP
for INSTANCE_IP in "$INSTANCE_IPS"; do
    echo "Processing instance: $INSTANCE_IP"

    # Remove any existing host key entry (to avoid conflicts)
    ssh-keygen -R "$INSTANCE_IP"

    # Add the instance to known_hosts (for ubuntu user)
    ssh-keyscan -H "$INSTANCE_IP" >> /home/ubuntu/.ssh/known_hosts
    chmod 600 /home/ubuntu/.ssh/known_hosts

    # Copy SSH key to the instance
    sshpass -p "${PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@"$INSTANCE_IP"

    # Sleep for 10 seconds between instances
    sleep 10
done

# Secure SSH settings
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
sudo sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication yes/#PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# --- Additional Steps for Jenkins User ---
echo "Configuring Jenkins SSH settings..."

# Ensure Jenkins SSH directory exists with correct permissions
sudo mkdir -p /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh

# Temporarily give ubuntu user permission to read private key
sudo chmod 644 /home/ubuntu/.ssh/id_rsa
sudo chmod 644 /home/ubuntu/.ssh/id_rsa.pub

# Copy SSH keys to Jenkins user
sudo cp /home/ubuntu/.ssh/id_rsa /var/lib/jenkins/.ssh/
sudo cp /home/ubuntu/.ssh/id_rsa.pub /var/lib/jenkins/.ssh/
sudo chmod 600 /var/lib/jenkins/.ssh/id_rsa
sudo chmod 644 /var/lib/jenkins/.ssh/id_rsa.pub
sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/id_rsa*
 
# Revoke ubuntu's read access to the private key
sudo chmod 600 /home/ubuntu/.ssh/id_rsa
sudo chmod 644 /home/ubuntu/.ssh/id_rsa.pub

# Add worker node to known_hosts for Jenkins
sudo -u jenkins ssh-keygen -R "$WORKER1_IP"
sudo -u jenkins ssh-keyscan -H "$WORKER1_IP" >> /var/lib/jenkins/.ssh/known_hosts
sudo chmod 600 /var/lib/jenkins/.ssh/known_hosts
sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/known_hosts

# Restart Jenkins to apply changes
echo "Restarting Jenkins..."
sudo systemctl restart jenkins
    
echo "Setup completed. Try adding the Jenkins agent now."
