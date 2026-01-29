#!/bin/env bash

#!/bin/env bash

sudo dnf update -y
sudo dnf install -y python3 python3-pip awscli

sudo pip3 install ansible boto3 --no-cache-dir

cat <<'EOF' > /home/ec2-user/inventory.ini
${inventory_content}
EOF

cat <<'EOF' > /home/ec2-user/ansible-lab-key.pem
${private_key_pem}
EOF

chmod 400 /home/ec2-user/ansible-lab-key.pem
chown ec2-user:ec2-user /home/ec2-user/inventory.ini /home/ec2-user/ansible-lab-key.pem

touch /home/ec2-user/.ansible_setup_complete