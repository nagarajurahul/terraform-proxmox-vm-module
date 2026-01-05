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

  # SSH Hardening Configuration
  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    permissions: '0644'
    owner: root:root
    content: |
      # SSH Hardening
      PermitRootLogin no
      PasswordAuthentication no
      PubkeyAuthentication yes
      ChallengeResponseAuthentication no
      UsePAM yes
      X11Forwarding no
      PrintMotd no
      AcceptEnv LANG LC_*
      Subsystem sftp /usr/lib/openssh/sftp-server
      ClientAliveInterval ${ssh_client_alive_interval}
      ClientAliveCountMax ${ssh_client_alive_count_max}
      MaxAuthTries ${ssh_max_auth_tries}
      MaxSessions ${ssh_max_sessions}

  # Sysctl Security Hardening
  - path: /etc/sysctl.d/99-security.conf
    permissions: '0644'
    owner: root:root
    content: |
      # Network Security
      net.ipv4.conf.all.rp_filter = 1
      net.ipv4.conf.default.rp_filter = 1
      net.ipv4.conf.all.accept_redirects = 0
      net.ipv4.conf.default.accept_redirects = 0
      net.ipv4.conf.all.secure_redirects = 0
      net.ipv4.conf.default.secure_redirects = 0
      net.ipv4.conf.all.send_redirects = 0
      net.ipv4.conf.default.send_redirects = 0
      net.ipv4.icmp_echo_ignore_broadcasts = 1
      net.ipv4.icmp_ignore_bogus_error_responses = 1
      net.ipv4.tcp_syncookies = 1

      # IPv6 Security
      net.ipv6.conf.all.accept_redirects = 0
      net.ipv6.conf.default.accept_redirects = 0

      # Kernel Hardening
      kernel.dmesg_restrict = 1
      kernel.kptr_restrict = 2

  # Fail2ban Configuration
  - path: /etc/fail2ban/jail.local
    permissions: '0644'
    owner: root:root
    content: |
      [DEFAULT]
      maxretry = ${fail2ban_max_retry}
      bantime = ${fail2ban_ban_time}
      findtime = ${fail2ban_find_time}

      [sshd]
      enabled = true
      port = ssh
      logpath = %(sshd_log)s
      backend = %(sshd_backend)s

  # Unattended Upgrades Configuration
  - path: /etc/apt/apt.conf.d/50unattended-upgrades
    permissions: '0644'
    owner: root:root
    content: |
      Unattended-Upgrade::Allowed-Origins {
          "$${distro_id}:$${distro_codename}-security";
          "$${distro_id}ESMApps:$${distro_codename}-apps-security";
          "$${distro_id}ESM:$${distro_codename}-infra-security";
      };
      Unattended-Upgrade::AutoFixInterruptedDpkg "true";
      Unattended-Upgrade::MinimalSteps "true";
      Unattended-Upgrade::Remove-Unused-Dependencies "true";
      Unattended-Upgrade::Automatic-Reboot "false";

  # Enable unattended upgrades completely non-interactively
  - path: /etc/apt/apt.conf.d/20auto-upgrades
    permissions: '0644'
    owner: root:root
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Download-Upgradeable-Packages "1";
      APT::Periodic::AutocleanInterval "7";
      APT::Periodic::Unattended-Upgrade "1";

  # Persistent journald logs (useful for debugging prod issues)
  - path: /etc/systemd/journald.conf.d/99-persistent.conf
    permissions: '0644'
    owner: root:root
    content: |
      [Journal]
      Storage=persistent
      SystemMaxUse=1G

  # Persistent auditd rules
  - path: /etc/audit/rules.d/99-hardening.rules
    permissions: '0640'
    owner: root:root
    content: |
      ###############################################
      # Clear existing rules
      ###############################################
      -D

      ###############################################
      # Buffer size & failure mode
      ###############################################
      -b 8192
      -f 1

      ###############################################
      # Identity files
      ###############################################
      -w /etc/passwd -p wa -k identity
      -w /etc/shadow -p wa -k identity
      -w /etc/group -p wa -k identity
      -w /etc/gshadow -p wa -k identity
      -w /etc/sudoers -p wa -k sudo_changes
      -w /etc/sudoers.d/ -p wa -k sudo_changes

      ###############################################
      # Network configuration
      ###############################################
      -w /etc/hosts -p wa -k network_config
      -w /etc/network/ -p wa -k network_config
      -w /etc/netplan/ -p wa -k network_config

      ###############################################
      # SSH configuration
      ###############################################
      -w /etc/ssh/sshd_config -p wa -k sshd_config
      -w /etc/ssh/sshd_config.d/ -p wa -k sshd_config

      ###############################################
      # Privileged command execution (execve)
      ###############################################
      -a always,exit -F arch=b64 -S execve -F euid=0 -k privileged_exec
      -a always,exit -F arch=b32 -S execve -F euid=0 -k privileged_exec

      ###############################################
      # Unauthorized access attempts
      ###############################################
      -a always,exit -F arch=b64 -S open,openat,creat -F exit=-EACCES -k access_denied
      -a always,exit -F arch=b64 -S open,openat,creat -F exit=-EPERM -k access_denied
      -a always,exit -F arch=b32 -S open,openat,creat -F exit=-EACCES -k access_denied
      -a always,exit -F arch=b32 -S open,openat,creat -F exit=-EPERM -k access_denied

      ###############################################
      # Kernel module loading/unloading
      ###############################################
      -w /sbin/insmod -p x -k kernel_modules
      -w /sbin/modprobe -p x -k kernel_modules
      -w /sbin/rmmod -p x -k kernel_modules

      -a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k kernel_modules
      -a always,exit -F arch=b32 -S init_module,finit_module,delete_module -k kernel_modules

      ###############################################
      # Cron changes
      ###############################################
      -w /etc/crontab -p wa -k cron
      -w /etc/cron.d/ -p wa -k cron
      -w /var/spool/cron/ -p wa -k cron

      ###############################################
      # Immutable flag - must be last
      ###############################################
      -e 2

##############################################
# User Configuration
#############################################
users:
%{ for username, user in users ~}
  - name: ${username}
    gecos: ${username}
    sudo: [ 'ALL=(ALL) NOPASSWD:ALL' ]
    groups: [ sudo, adm, systemd-journal ]
    shell: /bin/bash
    hashed_passwd: ${user.hashed_password}
    ssh_authorized_keys:
%{ for key in user.ssh_authorized_keys ~}
      - ${key}
%{ endfor ~}
    lock_passwd: ${LOCK_PASSWORD}
%{ endfor ~}

# Disable SSH password auth at cloud-init level too (matches sshd_config)
ssh_pwauth: false

# Disable root account login
disable_root: true

##############################################
# Package Management
#############################################
package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
##############################################
# Essential System Tools
##############################################
- sudo
- vim
- nano
- curl
- wget
- unzip
- zip
- ca-certificates
- gnupg
- lsb-release
- apt-transport-https
- software-properties-common

##############################################
# QEMU Guest Agent (Proxmox Integration)
##############################################
- qemu-guest-agent

##############################################
# Time Synchronization
##############################################
- chrony

##############################################
# Networking Tools
##############################################
- iproute2
- iputils-ping
- net-tools
- dnsutils
- traceroute
- netcat-openbsd
- mtr
- nmap
- tcpdump

##############################################
# System Monitoring & Performance
##############################################
- htop
- iotop
- iftop
- nmon
- ncdu
- sysstat
- lsof
- dstat
- strace
- linux-tools-generic # perf tools

##############################################
# Security & Hardening
##############################################
- openssh-server
- fail2ban
- unattended-upgrades
- auditd

##############################################
# Python Environment (for Ansible & Scripts)
##############################################
- python3
- python3-pip
- python3-apt

##############################################
# CLI Utilities & Tools
##############################################
- jq
- tree
- rsync
- bash-completion
- stat

##############################################
# Modern CLI Replacements
##############################################
- lsd # Modern 'ls' with colors and icons
- ripgrep # Fast 'grep' replacement (rg)
- fd-find # Fast 'find' replacement
- fzf # Fuzzy finder
- bat # 'cat' with syntax highlighting
- delta # Better git diff viewer
- dust # Modern 'du' replacement
- duf # Modern 'df' replacement

##############################################
# Boot Commands (Run Before Packages)
#############################################
bootcmd:
  - test -f /var/lib/cloud/bootcmd_done && exit 0 || touch /var/lib/cloud/bootcmd_done
  - echo "Ensuring network comes up before packages..." | tee -a /var/log/cloud-init-network.log
  - sleep 20
  - netplan generate
  - netplan apply || (sleep 5 && netplan apply)
  - systemctl restart systemd-networkd || true

  # Wait for IP address (POSIX-safe)
  - |
    for i in $(seq 1 30); do
      ip addr show | grep -q "inet .* scope global" && break
      echo "Waiting for IP address... attempt $i" | tee -a /var/log/cloud-init-network.log
      sleep 2
    done

##############################################
# Run Commands (After Package Installation)
#############################################
runcmd:
  # Update CA certificates
%{ if CA_ROOT_CRT != "" ~}
  - update-ca-certificates || true
%{ endif ~}

  # Make journald persistent
  - mkdir -p /var/log/journal
  - systemctl restart systemd-journald || true

  # Auditd
  - systemctl enable --now auditd || true
  - augenrules --load || service auditd restart || true

  # System Services
  - systemctl daemon-reload || true
  - systemctl enable --now qemu-guest-agent || true
  - systemctl restart qemu-guest-agent || true
  - systemctl enable --now ssh || true
  - systemctl restart ssh || true
  - systemctl enable --now chrony || true
  - systemctl enable --now fail2ban || true
  - systemctl restart fail2ban || true
  - systemctl enable --now systemd-resolved || true

  # Apply sysctl changes
  - sysctl -p /etc/sysctl.d/99-security.conf || true
  - sysctl --system || true

  # Set hostname
  - hostnamectl set-hostname ${HOSTNAME}

  # Configure timezone
  - timedatectl set-timezone UTC

  # Cleanup
  - apt-get autoremove -y
  - apt-get clean
  - sync

  # Log network configuration
  - ip addr show >> /var/log/cloud-init-network.log
  - ip route show >> /var/log/cloud-init-network.log
  - cat /etc/resolv.conf >> /var/log/cloud-init-network.log

  # Create success marker
  - |
    set -e
    echo "Cloud-init completed successfully on $(date)" | tee /var/log/cloud-init.success
    echo "Hostname: ${HOSTNAME}" >> /var/log/cloud-init.success
    echo "Environment: ${environment}" >> /var/log/cloud-init.success

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
