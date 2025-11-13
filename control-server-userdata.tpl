#cloud-config

hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.${DNS_DOMAIN}

manage_etc_hosts: true
timezone: UTC

write_files:
%{ if CA_ROOT_CRT != "" ~}
  - path: /usr/local/share/ca-certificates/custom_root_ca.crt
    permissions: '0644'
    content: |
      ${join("\n      ", split("\n", trimspace(CA_ROOT_CRT)))}
%{ endif ~}

users:
%{ for username, user in users ~}
  - name: ${username}
    gecos: ${username} ${HOSTNAME}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: [sudo]
    shell: /bin/bash
    hashed_passwd: ${user.hashed_password}
    ssh_authorized_keys:
%{ for key in user.ssh_authorized_keys ~}
      - ${key}
%{ endfor ~}
    lock_passwd: false
%{ endfor ~}

ssh_pwauth: true  # Enable password authentication for SSH

package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  # --- Base System & Utilities ---
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
  - qemu-guest-agent
  - chrony
  - bash-completion

  # --- System Monitoring & Performance ---
  - htop
  - iotop
  - iftop
  - nmon
  - sysstat
  - ncdu
  - iperf3
  - lsof

  # --- Networking & Troubleshooting ---
  - net-tools
  - dnsutils
  - traceroute
  - netcat-openbsd

  # --- Security & Access ---
  - openssh-server
  # - ufw
  - fail2ban

  # --- DevOps / IaC / Automation Tools ---
  - git
  - jq
  - yq
  - tmux
  - ansible
  - docker.io
  - python3
  - python3-pip

  # --- Cloud & Integration Tools ---
  - gh
  - rsync

bootcmd:
  - test -f /var/lib/cloud/bootcmd_done && exit 0 || touch /var/lib/cloud/bootcmd_done
  - echo "Ensuring network comes up before packages..." | tee -a /var/log/cloud-init-network.log
  - sleep 10
  - netplan generate
  - netplan apply || (sleep 5 && netplan apply)
  - systemctl restart systemd-networkd || true

runcmd:
%{ if CA_ROOT_CRT != "" ~}
  - update-ca-certificates
%{ endif ~}
  # --- Base System Setup ---
  - systemctl enable --now qemu-guest-agent
  - systemctl restart qemu-guest-agent || true
  - systemctl enable --now ssh
  - systemctl enable --now docker
  - usermod -aG docker ${default_user}
  - systemctl enable --now chrony
  - systemctl enable --now fail2ban
  
  # --- Security ---
  # - ufw allow OpenSSH
  # - ufw --force enable

  # --- Git Configuration ---
  - git config --global user.name ${git_username}
  - git config --global user.email ${git_email}

  # --- HashiCorp Repo & Terraform Installation ---
  - apt-get install -y gnupg software-properties-common apt-transport-https curl lsb-release
  - wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  - apt-get install -y terraform || true

  # --- Cleanup & Finalization ---
  - apt-get autoremove -y
  - sync
  - ip a >> /var/log/cloud-init-network.log
  - echo "Welcome to ${HOSTNAME}" > /etc/motd
  - echo "Cloud Init completed successfully on $(date)" | tee -a /var/log/cloud-init-done.log
  - touch /var/log/cloud-init.success

final_message: "Cloud-init completed on ${HOSTNAME} at $(date -u)"
