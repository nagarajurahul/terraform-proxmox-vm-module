#cloud-config

hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.homelab.local
manage_etc_hosts: true

users:
%{ for username, user in users ~}
  - name: ${username}
    gecos: ${username} ${HOSTNAME}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: users, admin, sudo, docker
    shell: /bin/bash
    ssh-authorized-keys:
%{ for key in user.ssh_authorized_keys ~}
      - ${key}
%{ endfor ~}
    lock_passwd: false
%{ endfor ~}

# Allow password login (required for OVF 'password' to work)
ssh_pwauth: true

chpasswd:
  list: |
%{ for username, user in users ~}
    ${username}:${user.password}
%{ endfor ~}
  expire: False

system_info:
  default_user:
    name: ${default_user}
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash

package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  # --- Base System & Utilities ---
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
  - qemu-guest-agent

  # --- System Monitoring & Performance ---
  - htop
  - iotop
  - iftop
  - nmon
  - sysstat
  - ncdu
  - iperf3

  # --- Networking & Troubleshooting ---
  - net-tools
  - dnsutils
  - traceroute

  # --- Security & Access ---
  - openssh-server
  - ufw
  - fail2ban

  # --- DevOps / IaC / Automation Tools ---
  - git
  - jq
  - yq
  - tmux
  - ansible
  - docker.io
  - docker-compose-plugin
  - python3
  - python3-pip

  # --- Cloud & Integration Tools ---
  - awscli
  - gh

runcmd:
  # --- System Setup ---
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now ssh
  - systemctl enable --now docker
  - usermod -aG docker ${default_user}

  # --- Security ---
  - ufw allow OpenSSH
  - ufw --force enable

  # --- Git Configuration ---
  - git config --global user.name ${git_username}
  - git config --global user.email ${git_email}
   
  # --- HashiCorp Repo & Terraform Installation ---
  - bash -c "wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
  - bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP \"(?<=UBUNTU_CODENAME=).*\" /etc/os-release || lsb_release -cs) main' > /etc/apt/sources.list.d/hashicorp.list"
  - apt update
  - apt install -y terraform

  # --- Cleanup ---
  - apt autoremove -y

  # --- Message ---
  - ip a >> /var/log/cloud-init-network.log
  - echo "Welcome to ${HOSTNAME}" > /etc/motd
  - echo "Cloud Init completed successfully. $(date)" >> /var/log/cloud-init-done.log