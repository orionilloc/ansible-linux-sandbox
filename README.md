# Ansible Linux Sandbox

A multi-distro Ansible automation lab built on AWS, evolved across three architectural versions.
Each version exists because the previous one had a concrete problem: keys on disk, static
inventory that broke on instance replacement, no gate between a bad playbook and live nodes.

The progression is the point. The full writeup lives in the [blog series](https://orionilloc.github.io).

---

## 📈 Evolution Overview

| Version | Connectivity | State | Nodes | Inventory |
|---|---|---|---|---|
| v1 — Legacy SSH | SSH + public IP | Local | 4 (AL2023, Debian, Ubuntu, Arch) | Static, templated at apply |
| v2 — Remote State + SSM | SSM, no public IPs | S3 + DynamoDB | 6 (AL2023, Debian, Ubuntu, Fedora, RHEL, openSUSE) | Static, templated at apply |
| v3 — Dynamic Inventory | SSM, no public IPs | S3 + DynamoDB | 6 (AL2023, Debian, Ubuntu, Fedora, RHEL, openSUSE) | Dynamic via `aws_ec2` plugin |

---

## 🔑 v1 — Legacy SSH

SSH-based connectivity, local Terraform state, public IP on the control node. Terraform generates
an RSA key pair at apply time and renders the inventory from a template. Works for a clean build,
breaks the moment a single instance needs replacement.

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

SSM replaces SSH. The control node moves to the private subnet with no public IP and no inbound
rules. State moves to S3 with DynamoDB locking. The node count expands to six distros, each with
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

The `inventory.ini` is replaced by the `amazon.aws.aws_ec2` plugin. The plugin queries the AWS
API at runtime and builds inventory from EC2 tags. Instance replacements are reflected
automatically on the next run without a Terraform apply or manual inventory edit.

Roles were built during this phase: `universal-baseline` for common configuration across all
six distros, and `os-hardening` for a scoped subset of CIS benchmark controls.

Firewalld was evaluated and dropped. Security groups enforce equivalent rules at the hypervisor
level. Managing firewalld cross-distro added complexity without adding a meaningful security
boundary.

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

# Verify connectivity from the control node
aws ssm start-session --target=<ansible_control_id>
ansible linux -m ping
```
