#cloud-config

##############################################
# System Identity
#############################################

hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.${DNS_DOMAIN}

manage_etc_hosts: true
prefer_fqdn_over_hostname: true

timezone: UTC

##############################################
# Write Files Before Package Installation
#############################################
write_files:
  # Root CA Certificate
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
    gecos: ${username}
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

# Disable SSH password auth at cloud-init level too (matches sshd_config)
ssh_pwauth: false

##############################################
# Package Management
#############################################
package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
# Essential System Tools
- sudo
- curl
- wget
- ca-certificates
- gnupg
- lsb-release
- apt-transport-https
- software-properties-common

# QEMU Guest Agent (for Proxmox / IP reporting)
- qemu-guest-agent

# Time Synchronization
- chrony

# Networking Tools
- iproute2
- iputils-ping
- net-tools
- dnsutils
- traceroute
- netcat-openbsd

# System Monitoring
- htop
- iotop
- ncdu
- sysstat
- lsof

# Security
- openssh-server
- fail2ban
- unattended-upgrades

# Python (for Ansible)
- python3
- python3-pip
- python3-apt

# Miscellaneous
- vim
- rsync
- bash-completion

##############################################
# Boot Commands (Run Before Packages)
#############################################
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

  # Make journald persistent
  - mkdir -p /var/log/journal
  - systemctl restart systemd-journald

  # System Services
  - systemctl daemon-reload
  - systemctl enable --now qemu-guest-agent
  - systemctl restart qemu-guest-agent
  - systemctl enable --now ssh
  - systemctl enable --now chrony
  - systemctl enable --now fail2ban
  - systemctl enable --now systemd-resolved
  
  # Apply sysctl changes
  - sysctl --system
  
  # Set hostname
  - hostnamectl set-hostname ${HOSTNAME}
  
  # Configure timezone
  - timedatectl set-timezone UTC
  
  # Enable unattended upgrades
  - dpkg-reconfigure -plow unattended-upgrades
  
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


##############################################
# Final Configuration
##############################################
power_state:
  mode: reboot
  condition: True
  timeout: 30
  delay: now

final_message: |
  ====================================
  Cloud-init setup complete!
  Hostname: ${HOSTNAME}
  FQDN: ${HOSTNAME}.${DNS_DOMAIN}
  Environment: ${environment}
  ====================================
