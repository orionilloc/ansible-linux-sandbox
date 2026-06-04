# Ansible Linux Sandbox

A multi-distro Ansible automation lab built on AWS, evolved across three architectural versions. The goal was to move from a tutorial-style SSH setup toward something that reflects how infrastructure is actually managed in production — private networking, IAM-based authentication, role-based configuration management, and a CI/CD pipeline that catches problems before they reach live infrastructure.

---

## Evolution Overview

| Version | Connectivity | State | Nodes | Inventory |
|---|---|---|---|---|
| v1 — Legacy SSH | SSH + public IP | Local | 4 (AL2023, Debian, Ubuntu, Arch) | Static, templated at apply |
| v2 — Remote State + SSM | SSM, no public IPs | S3 + DynamoDB | 6 (AL2023, Debian, Ubuntu, Fedora, RHEL, openSUSE) | Static, templated at apply |
| v3 — Dynamic Inventory | SSM, no public IPs | S3 + DynamoDB | 6 | Dynamic via `aws_ec2` plugin |

---

## v1 — Legacy SSH

The starting point. Four nodes, SSH-based connectivity, local Terraform state, and a public IP on the control node.

**How it worked:**
Terraform generates an RSA key pair at apply time using the `tls` provider, uploads the public key to AWS, and writes the private key to a local `.pem` file. The control node gets a public IP and an inbound rule on port 22. Managed nodes live in a private subnet and only accept SSH from the control node's security group.

The inventory and `ansible.cfg` are rendered dynamically from template files at apply time — private IPs get interpolated into `inventory.ini`, the key path gets wired up, and everything lands on the control node via `user_data`. Strict host key checking is disabled to avoid first-connection prompts.

**What didn't work:**
Arch Linux. It's in the inventory, it never reliably worked — dependency issues, race conditions in the bootstrap, and honestly Arch isn't something you'd encounter managing real infrastructure. It's there. It's broken. Moving on.

The bigger structural problem with this version: templating the inventory at apply time means if you ever need to replace a single EC2 instance with `terraform -replace`, the inventory doesn't update cleanly. The whole apply has to run. It works for a clean build, not for ongoing management. You'd need to manually update values which is tedious and error-prone.

**Key files:**
```
v1-legacy-ssh/
├── main.tf          # EC2 instances, key pair, IAM
├── networking.tf    # VPC, public/private subnets, NAT gateway
├── security.tf      # SGs: port 22 inbound on control, SSH from control to managed
├── variables.tf
├── outputs.tf
├── user-data.sh     # HEREDOC-based: inventory, key file, ansible.cfg
├── inventory.ini    # Template — IPs interpolated at apply
└── ansible.cfg
```

---

## v2 — Remote State + SSM

SSM replaces SSH, remote state replaces local state, the node count expands to six distros, and the control node loses its public IP entirely.

### Bootstrap

Before the main infrastructure can use remote state, the state backend itself has to exist. `bootstrap-ansible-linux-sandbox/` is a separate Terraform root module that provisions the S3 bucket and DynamoDB lock table. You run it once, commit the lock file, and never touch it again.

```
bootstrap-ansible-linux-sandbox/
└── main.tf    # S3 bucket (versioned) + DynamoDB table
```

### SSM as the Connection Layer

Switching from SSH to SSM required more than changing `ansible_connection` in the inventory. A few things that had to change:

**IAM policies.** The SSM connection plugin uses S3 as a transport layer — Ansible modules are uploaded to a bucket, executed on the managed node, and results are written back. The instance profile needed explicit `s3:PutObject`, `s3:GetObject`, and `s3:DeleteObject` permissions on that bucket, plus a `Deny` on the Terraform state prefix so the control node couldn't accidentally touch state files.

**No more public IP on the control node.** Without SSH, there's no reason for the control node to be reachable from the internet. It moves to the private subnet. You access it via `aws ssm start-session` from your local machine — same IAM credentials, no exposed port.

**S3 transport vs SSH transport.** SSH-based Ansible transfers modules over the SSH connection itself, which has byte limits. The SSM plugin routes module transfer through S3, which removes that constraint and performs better when running tasks across multiple nodes simultaneously.

### Expanding to Six Distros

Adding Fedora, RHEL, and openSUSE surfaced distro-specific bootstrapping issues that v1 never had to deal with.

**SSM agent availability.** AL2023 and Ubuntu ship with the SSM agent. Debian, Fedora, RHEL, and openSUSE don't. Each of those nodes has a `user_data` script that installs and enables it before Terraform considers the instance ready. The control node has a `depends_on` block waiting for all managed nodes to exist before rendering the inventory.

**The zypper problem.** openSUSE's package manager initializes asynchronously on first boot. Trying to install python3 immediately in `user_data` fails because zypper hasn't finished its own setup. The fix is an until loop:

```bash
until zypper refresh; do
  echo "zypper not ready. Retrying..."
  sleep 5
done
zypper install -y python3
```

Brittle? Arguably. But these are ephemeral nodes — if something goes wrong you tear them down and apply again. That's the point of infrastructure as code.

**Bracketed paste mode.** RHEL-family nodes (RHEL, Fedora) have bracketed paste enabled by default in `/etc/inputrc`. This causes terminal noise when SSM sessions paste content — control sequences appear as literal characters. Fixed by appending `set enable-bracketed-paste off` to `/etc/inputrc` and `/etc/skel/.inputrc` in `user_data`.

**Security groups.** The control node's security group has egress-only rules — no inbound at all. Managed nodes accept all traffic from the control node's security group and nothing else. SSM connectivity doesn't require any inbound rules because the agent initiates outbound connections to the AWS service endpoint.

**Key files:**
```
v2-remote-state-ssm/
├── main.tf          # Backend config, EC2, IAM with S3 + SSM policies
├── networking.tf    # Same VPC layout, control node now in private subnet
├── security.tf      # Egress-only control SG, no SSH rules anywhere
├── variables.tf
├── outputs.tf
├── user-data.sh     # set -euo pipefail, SSM plugin install, ansible setup
├── inventory.ini    # Template — instance IDs interpolated (not IPs)
└── ansible.cfg      # SSM connection vars
```

Note that the inventory now uses instance IDs rather than private IPs. SSM targets instances by ID, not by network address.

---

## v3 — Dynamic Inventory

The main infrastructure is unchanged. The single addition is replacing the statically templated `inventory.ini` with a dynamic inventory plugin.

```yaml
# aws_ec2.yml
plugin: aws_ec2
regions:
  - us-east-1
filters:
  tag:Project: ansible-lab
  instance-state-name: running
keyed_groups:
  - key: tags.Distro
    prefix: distro
```

The plugin queries the AWS API at runtime and builds the inventory from EC2 tags. This solves the `terraform -replace` problem from v1 — if a node is replaced, the next Ansible run sees the new instance ID automatically without a full Terraform apply.

**Key files:**
```
v3-dynamic-inventory/
├── aws_ec2.yml      # Dynamic inventory plugin config
└── ansible.cfg      # Points to aws_ec2.yml instead of inventory.ini
```

---

## Ansible Roles

I started working on actual Ansible playbooks around halfway through my v2 commits. 

Configuration management is split into two roles with a clear separation of concerns.

```
roles/
├── universal-baseline/
│   ├── tasks/
│   │   ├── main.yml       # Task router
│   │   ├── packages.yml   # Common packages via `package` module
│   │   ├── timezone.yml   # Systemd timedatectl
│   │   └── motd.yml       # /etc/motd
│   ├── defaults/
│   │   └── main.yml
│   └── handlers/
│       └── main.yml
│
└── os-hardening/
    ├── tasks/
    │   ├── main.yml        # Task router
    │   ├── sysctl.yml      # Kernel parameter hardening
    │   ├── sshd.yml        # Disable sshd service
    │   └── filesystem.yml  # Sticky bits on /tmp and /var/tmp
    ├── defaults/
    │   └── main.yml        # Toggleable controls
    └── handlers/
        └── main.yml
```

### universal-baseline

Applied to every node. Uses the `package` module throughout — it maps to `apt`, `dnf`, `yum`, or `zypper` at runtime, so the same task file works across all six distros without conditionals.

### os-hardening

**sysctl** — Uses `ansible.posix.sysctl` rather than a `shell` module call. The distinction matters: the shell module can't tell the difference between "I just set this value" and "this value was already correct." `ansible.posix.sysctl` reports `changed` vs `ok` accurately, which is what makes a playbook genuinely idempotent.

**sshd** — Debian and Ubuntu name the SSH daemon `ssh`. RHEL-family distros name it `sshd`. Rather than two separate task files, a single task uses an `ansible_os_family` conditional to resolve the correct service name at runtime.

**filesystem** — Sticky bits on `/tmp` and `/var/tmp`. Prevents unprivileged users from deleting files they don't own in world-writable directories.

**firewalld** — Evaluated and dropped. Present by default on Fedora, RHEL, and openSUSE. In this environment it's redundant — security groups enforce the same rules at the hypervisor level. Managing it cross-distro added noise without adding a meaningful security boundary.

**Toggleable controls** — Every hardening control has a corresponding boolean in `defaults/main.yml`. Controls can be disabled per environment without modifying task logic.

### Playbooks

```
playbooks/
├── site.yml      # Runs universal-baseline across all nodes
└── harden.yml    # Runs os-hardening across all nodes
```

---

## CI/CD Pipeline

Two GitHub Actions workflows run on every pull request.

**`terraform-ci.yml`**
- `terraform fmt -check` — formatting is enforced, not suggested
- `terraform validate` — structural validation before any plan runs

**`ansible-ci.yml`**
- `ansible-lint` — style and idempotency pattern enforcement
- `ansible-playbook --syntax-check` — task structure validation without connecting to hosts
- Installs collections from `collections/requirements.yml` (`community.general`, `ansible.posix`)

Neither workflow touches live infrastructure. The gate exists to catch problems in the diff.

## Prerequisites

```bash
# Provision the state backend
cd v2-remote-state-ssm/bootstrap-ansible-linux-sandbox
terraform init && terraform apply

# Main infrastructure
cd ..
terraform init
terraform apply

# Verify access on the control node after five minutes of cooking
aws ssm start-session --target <ansible_control_id> --region us-east-1
ansible linux -m ping
```
