#cloud-config
hostname: {{ .hostname }}
manage_etc_hosts: true
users:
  - name: root
    ssh_authorized_keys:
{{ range .ssh_keys }}
      - {{ . }}
{{ end }}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
package_update: true
package_upgrade: true
runcmd:
  - [ apt-get, update ]
  - [ apt-get, install, -y, curl ]