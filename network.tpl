#cloud-config
network:
  version: 2
  ethernets:
    # Match all interfaces with the name en, because interface names can change
    # all-en:
    #   match:
    #     name: "en*"
    # Match all interfaces with driver name and set interface name as eth0
    driver0:
      match:
        driver: "${DRIVER}"
      set-name: eth0
      dhcp4: true
      dhcp4-overrides:
        use-dns: false
      nameservers:
        addresses: [${DNS_SERVERS}]
        search: [${DNS_DOMAIN}]
