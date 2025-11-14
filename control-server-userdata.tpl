#cloud-config

##############################################
# System Identity
#############################################
hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.${DNS_DOMAIN}

manage_etc_hosts: true
prefer_fqdn_over_hostname: true

# Set timezone
timezone: UTC

##############################################
# Write Files Before Package Installation
#############################################
write_files:
%{ if CA_ROOT_CRT != "" ~}
  - path: /usr/local/share/ca-certificates/custom_root_ca.crt
    permissions: '0644'
    owner: root:root
    content: |
      ${join("\n      ", split("\n", trimspace(CA_ROOT_CRT)))}
%{ endif ~}

##############################################
# User Configuration
#############################################
users:
%{ for username, user in users ~}
  - name: ${username}
    gecos: ${username} ${HOSTNAME}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: [ sudo, adm, systemd-journal ]
    shell: /bin/bash
    hashed_passwd: ${user.hashed_password}
    ssh_authorized_keys:
%{ for key in user.ssh_authorized_keys ~}
      - ${key}
%{ endfor ~}
    lock_passwd: false
%{ endfor ~}

# Enable password authentication for SSH in Lab (disable in production
ssh_pwauth: true

# Disable root login in production
# disable_root: true

package_update: true
package_upgrade: true
package_reboot_if_required: true

##############################################
# Package Management
#############################################
packages:
# Essential Tools
- sudo
- vim
- nano
- curl
- wget
- unzip
- zip
- tree
- gnupg
- lsb-release
- ca-certificates
- software-properties-common
- apt-transport-https

# QEMU Guest Agent
- qemu-guest-agent

# Time Sync
- chrony

# Networking
- net-tools
- dnsutils
- traceroute
- netcat-openbsd
- iproute2
- iputils-ping

# Monitoring
- htop
- iotop
- iftop
- nmon
- sysstat
- ncdu
- iperf3
- lsof

# Security
- openssh-server
- fail2ban
- unattended-upgrades

# DevOps Tools
- git
- jq
- yq
- tmux
- ansible
- python3
- python3-pip
- python3-apt

# GitHub CLI
- gh

# Miscellaneous
- rsync
- bash-completion


##############################################
# Boot Commands (Run Before Packages)
############################################
bootcmd:
  - test -f /var/lib/cloud/bootcmd_done && exit 0 || touch /var/lib/cloud/bootcmd_done
  - echo "Ensuring network comes up before packages..." | tee -a /var/log/cloud-init-network.log
  - sleep 10
  - netplan generate
  - netplan apply || (sleep 5 && netplan apply)
  - systemctl restart systemd-networkd || true

##############################################
# Run Commands (After Package Installation)
#############################################
runcmd:
  # Update CA certificates
%{ if CA_ROOT_CRT != "" ~}
  - update-ca-certificates
%{ endif ~}
  
  # System Services
  - systemctl daemon-reload
  - systemctl enable --now qemu-guest-agent
  - systemctl restart qemu-guest-agent
  - systemctl enable --now ssh
  - systemctl enable --now chrony
  - systemctl enable --now fail2ban
  - systemctl enable --now systemd-resolved

  # Apply sysctl changes
  - sysctl -p /etc/sysctl.d/99-security.conf

  # Set hostname
  - hostnamectl set-hostname ${HOSTNAME}
  
  # Configure timezone
  - timedatectl set-timezone UTC
  
  # Enable unattended upgrades
  - dpkg-reconfigure -plow unattended-upgrades

  # Git Configuration for all users
  - git config --system user.name "${git_username}"
  - git config --system user.email "${git_email}"
  - git config --system init.defaultBranch main
  
  # Install HashiCorp Repository
  - wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  - apt-get update
  
  # Install Terraform
  - apt-get install -y terraform
  
  # Install Ansible Collections
  - ansible-galaxy collection install community.general community.docker
  
  # Create project directories
  - mkdir -p /opt/projects/{terraform,ansible,scripts}
  - chown -R ${default_user}:${default_user} /opt/projects
  
  # Cleanup
  - apt-get autoremove -y
  - apt-get clean
  - sync
  
  # Log network configuration
  - ip addr show >> /var/log/cloud-init-network.log
  - ip route show >> /var/log/cloud-init-network.log
  - cat /etc/resolv.conf >> /var/log/cloud-init-network.log

  # Create success marker
  - echo "Cloud-init completed successfully on $(date)" | tee /var/log/cloud-init.success
  - echo "Hostname: ${HOSTNAME}" | tee -a /var/log/cloud-init.success
  - echo "Environment: ${environment}" | tee -a /var/log/cloud-init.success

  # Log app configuration
  - terraform version >> /var/log/cloud-init.success 2>&1
  - ansible --version >> /var/log/cloud-init.success 2>&1

final_message: "Cloud-init completed on ${HOSTNAME} at $(date -u)"
