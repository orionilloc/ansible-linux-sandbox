# Ansible Linux Sandbox

A multi-distro Ansible automation lab built on AWS, showing evolution across three architectural versions.
Each version exists because the previous one had a concrete problem: keys on disk, static
inventory that broke on instance replacement, or no gating between a faulty playbook and live nodes.

The full writeup lives here: [Part 1](https://orionilloc.github.io/posts/AnsibleLinuxSandboxPart1/) | [Part 2](https://orionilloc.github.io/posts/AnsibleLinuxSandboxPart2/) | [Part 3](https://orionilloc.github.io/posts/AnsibleLinuxSandboxPart3/) | [Part 4](https://orionilloc.github.io/posts/AnsibleLinuxSandboxPart4/)

---

## 📈 Overview

| Version | Connectivity | State | Nodes | Inventory |
|---|---|---|---|---|
| v1 — Legacy SSH | SSH + public IP | Local | 4 (AL2023, Debian, Ubuntu, Arch) | Static, templated at apply |
| v2 — Remote State + SSM | SSM, no public IPs | S3 + file locking | 6 (AL2023, Debian, Ubuntu, Fedora, RHEL, openSUSE) | Static, templated at apply |
| v3 — Dynamic Inventory | SSM, no public IPs | S3 + file locking | 6 (AL2023, Debian, Ubuntu, Fedora, RHEL, openSUSE) | Dynamic via `aws_ec2` plugin |

---

## 🔑 v1 — Legacy SSH

Looks more like a traditional server architecture. Uses default SSH-based connectivity, local Terraform state, and a public IP on the control node. Terraform generates an RSA key pair at apply time and renders the inventory from a template. This works for a clean build,
but breaks the moment a single instance needs to be replaced.

```
v1-legacy-ssh/
├── main.tf
├── networking.tf
├── security.tf
├── variables.tf
├── outputs.tf
├── user-data.sh
├── inventory.ini
└── ansible.cfg
```

---

## 🔒 v2 — Remote State + SSM

SSM replaces SSH as a remote management tool. The control node moves to the private subnet with no public IP and no inbound
rules. State moves to S3 with file locking. The node count expands to six distros, each with
distro-specific bootstrapping handled in `user_data`.

A separate bootstrap module provisions the state backend before the main infrastructure runs.

```
v2-remote-state-ssm/
├── bootstrap-ansible-linux-sandbox/
│   └── main.tf
├── main.tf
├── networking.tf
├── security.tf
├── variables.tf
├── outputs.tf
├── user-data.sh
├── inventory.ini
└── ansible.cfg
```

---

## ⚡ v3 — Dynamic Inventory + Roles

The local `inventory.ini` is replaced by the `amazon.aws.aws_ec2` plugin. The plugin queries the AWS
API at runtime and builds inventory from EC2 tags. Instance replacements are reflected
automatically on the next run without a Terraform apply or manual inventory edit.

Two roles were built during this phase: `universal-baseline` for common configuration across all
six distros, and `os-hardening` for a scoped subset of CIS benchmark controls.

Firewalld was evaluated and dropped. Security groups enforce access control at the network layer, and kernel-level network hardening (source-route rejection, SYN cookies, IP forwarding disabled) is applied via sysctl independently of firewalld. Managing firewalld cross-distro added complexity without closing a gap the existing controls didn't already cover. Additional CIS controls exist beyond this scope; these were chosen to keep the role legible rather than exhaustive.

```
v3-dynamic-inventory/
├── inventory/
│   └── aws_ec2.yml
├── ansible.cfg
├── playbooks/
│   ├── site.yml
│   └── harden.yml
└── roles/
    ├── universal-baseline/
    │   ├── defaults/main.yml
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── packages.yml
    │   │   ├── system.yml
    │   │   └── users.yml
    │   └── templates/
    └── os-hardening/
        ├── defaults/main.yml
        └── tasks/
            ├── main.yml
            ├── sysctl.yml
            ├── sshd.yml
            └── filesystem.yml
```

---

## ⚙️ CI/CD Pipeline

Two GitHub Actions workflows run on every pull request targeting main. Neither touches live
infrastructure.

`terraform-ci.yml` runs `terraform fmt -check` and `terraform validate`.

`ansible-ci.yml` runs `ansible-lint` and `ansible-playbook --syntax-check`. Collections are
installed from `collections/requirements.yml` at workflow runtime.

OIDC authentication is used to assume an AWS IAM role. No long-lived credentials are stored as
repository secrets.

---

## 🚀 Deployment

```bash
# Assumes valid AWS credentials are configured in your environment
# Export AWS_PROFILE=your-profile or use instance profile / env vars
# Provision the state backend (once)
cd v2-remote-state-ssm/bootstrap-ansible-linux-sandbox
terraform init && terraform apply

# Main infrastructure
cd ..
terraform init
terraform apply

# Wait at least five to ten minutes for instances to come online; this could probably be automated with SSM somehow

# Remote in and verify connectivity from the control node
aws ssm start-session --target=<ansible_control_id>
sudo su ec2-user
cd ~
ansible linux -m ping
```
