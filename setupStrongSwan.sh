#!/bin/sh
#https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ikev2-vpn-server-with-strongswan-on-ubuntu-16-04

server_ip=$1
user_name=$2
user_pass=$3
noaptupdate=$4

if [ -z ${server_ip} ] || [ -z ${user_name} ] || [ -z ${user_pass} ]; then
        echo "Usage: $0 server_ip user_name user_pass [noaptupdate]"
        exit 1
fi

set -x #echo on

if [ -z $noaptupdate ] || [ $noaptupdate != "noaptupdate" ]; then
  apt update
fi

apt -y install netfilter-persistent
apt -y install strongswan
apt -y install strongswan-plugin-eap-mschapv2
apt -y install moreutils
apt -y install iptables-persistent

mkdir vpn_certs

cd vpn_certs

ipsec pki --gen --type rsa --size 4096 --outform pem > server-root-key.pem

chmod 600 server-root-key.pem

ipsec pki --self --ca --lifetime 3650 \
--in server-root-key.pem \
--type rsa --dn "C=US, O=VPN Server, CN=VPN Server Root CA" \
--outform pem > server-root-ca.pem

ipsec pki --gen --type rsa --size 4096 --outform pem > vpn-server-key.pem

ipsec pki --pub --in vpn-server-key.pem \
--type rsa | ipsec pki --issue --lifetime 1825 \
--cacert server-root-ca.pem \
--cakey server-root-key.pem \
--dn "C=US, O=VPN Server, CN=${server_ip}" \
--san "'"${server_ip}"'" \
--flag serverAuth --flag ikeIntermediate \
--outform pem > vpn-server-cert.pem

cp ./vpn-server-cert.pem /etc/ipsec.d/certs/vpn-server-cert.pem

cp ./vpn-server-key.pem /etc/ipsec.d/private/vpn-server-key.pem

chown root /etc/ipsec.d/private/vpn-server-key.pem

chgrp root /etc/ipsec.d/private/vpn-server-key.pem

chmod 600 /etc/ipsec.d/private/vpn-server-key.pem

cp /etc/ipsec.conf /etc/ipsec.conf.original

cat > /etc/ipsec.conf <<EOF
config setup
  charondebug="ike 1, knl 1, cfg 0"
  uniqueids=no

conn ikev2-vpn
  auto=add
  compress=no
  type=tunnel
  keyexchange=ikev2
  fragmentation=yes
  forceencaps=yes

  #ike=aes256-sha1-modp1024,3des-sha1-modp1024!
  #esp=aes256-sha1,3des-sha1!

  ike=aes256gcm16-sha256-ecp521,aes256-sha256-ecp384!,aes256-sha1-modp1024,3des-sha1-modp1024!
  esp=aes256gcm16-sha256!,aes256-sha1,3des-sha1!

  dpdaction=clear
  dpddelay=300s
  rekey=no

  left=%any
  leftid=${server_ip}
  leftcert=/etc/ipsec.d/certs/vpn-server-cert.pem
  leftsendcert=always
  leftsubnet=0.0.0.0/0

  right=%any
  rightid=%any
  rightauth=eap-mschapv2
  rightsourceip=10.10.10.0/24
  rightdns=8.8.8.8,1.1.1.1
  rightsendcert=never

  eap_identity=%identity
EOF

cat > /etc/ipsec.secrets <<EOF
${server_ip} : RSA "/etc/ipsec.d/private/vpn-server-key.pem"
${user_name} %any% : EAP "${user_pass}"
EOF

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p udp --dport  500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s 10.10.10.10/24 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.10.10.10/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.10/24 -o eth0 -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.10/24 -o eth0 -j MASQUERADE
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.10/24 -o eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

ipsec restart
ipsec listcerts

echo vpn client cert
cat vpn_certs/server-root-ca.pem

echo "check ssh connection, if all ok run commands:"
echo "netfilter-persistent save"
echo "netfilter-persistent reload"
