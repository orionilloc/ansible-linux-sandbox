#!/bin/env bash

sudo dnf update -y
sudo dnf install -y python3 python3-pip awscli

sudo pip3 install ansible boto3 --no-cache-dir

curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo dnf install -y session-manager-plugin.rpm

cat <<'EOF' > /home/ec2-user/inventory.ini
${inventory_content}
EOF

cat <<'EOF' > /home/ec2-user/ansible.cfg
${ansible_configuration}
EOF

chown ec2-user:ec2-user /home/ec2-user/inventory.ini /home/ec2-user/ansible.cfg

touch /home/ec2-user/.ansible_setup_complete
