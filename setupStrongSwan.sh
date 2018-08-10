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

if [ -z ${noaptupdate} ] || [ ${noaptupdate} != "noaptupdate" ]; then
  apt update
fi

apt -y install netfilter-persistent
#apt -y install strongswan # v5.3.5 for ubuntu 16.04
#apt -y install strongswan-plugin-eap-mschapv2
apt -y install moreutils
apt -y install iptables-persistent

# for make strongswan
apt -y install libgmp-dev
apt -y install libssl-dev
apt -y install libxml2-dev
apt -y install libpcsclite-dev
apt -y install libpam0g-dev
apt -y install libiptcdata0-dev
apt -y install iptables-dev
apt -y install pkg-config

STRONGSWAN_VERSION="5.5.0"

mkdir -p /usr/src/strongswan \
	&& cd /usr/src \
	&& curl -SOL "https://download.strongswan.org/strongswan-$STRONGSWAN_VERSION.tar.gz" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& tar -zxf strongswan-$STRONGSWAN_VERSION.tar.gz -C /usr/src/strongswan --strip-components 1 \
	&& cd /usr/src/strongswan \
	&& ./configure --prefix=/usr --sysconfdir=/etc \
--enable-charon \
--enable-counters \
--enable-curve25519 \
--enable-des \
--enable-mgf1 \
--enable-test-vectors \
--enable-aes \
--enable-rc2 \
--enable-sha1 \
--enable-sha2 \
--enable-md4 \
--enable-md5 \
--enable-random \
--enable-nonce \
--enable-x509 \
--enable-revocation \
--enable-constraints \
--enable-pubkey \
--enable-pkcs1 \
--enable-pkcs7 \
--enable-pkcs8 \
--enable-pkcs12 \
--enable-pgp \
--enable-dnskey \
--enable-sshkey \
--enable-pem \
--enable-openssl \
--enable-fips-prf \
--enable-gmp \
--enable-agent \
--enable-xcbc \
--enable-cmac \
--enable-hmac \
--enable-gcm \
--enable-attr \
--enable-kernel-netlink \
--enable-resolve \
--enable-socket-default \
--enable-connmark \
--enable-farp \
--enable-stroke \
--enable-updown \
--enable-eap-identity \
--enable-eap-sim \
--enable-eap-sim-pcsc \
--enable-eap-aka \
--enable-eap-aka-3gpp2 \
--enable-eap-simaka-pseudonym \
--enable-eap-simaka-reauth \
--enable-eap-md5 \
--enable-eap-gtc \
--enable-eap-mschapv2 \
--enable-eap-dynamic \
--enable-eap-radius \
--enable-eap-tls \
--enable-eap-ttls \
--enable-eap-peap \
--enable-eap-tnc \
--enable-xauth-generic \
--enable-xauth-eap \
--enable-xauth-pam \
--enable-xauth-noauth \
--enable-tnc-tnccs \
--enable-tnccs-20 \
--enable-tnccs-11 \
--enable-tnccs-dynamic \
--enable-dhcp \
--enable-lookip \
--enable-error-notify \
--enable-certexpire \
--enable-led \
--enable-addrblock \
--enable-unity \
 && make -j \
 && make install \
 && rm -rf "/usr/src/strongswan*"

cd /home

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
--san "${server_ip}" \
--flag serverAuth --flag ikeIntermediate \
--outform pem > vpn-server-cert.pem

cp ./vpn-server-cert.pem /etc/ipsec.d/certs/vpn-server-cert.pem

cp ./vpn-server-key.pem /etc/ipsec.d/private/vpn-server-key.pem

chown root /etc/ipsec.d/private/vpn-server-key.pem

chgrp root /etc/ipsec.d/private/vpn-server-key.pem

chmod 600 /etc/ipsec.d/private/vpn-server-key.pem

cp /etc/ipsec.conf /etc/ipsec.conf.original

cd ..

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

cat > /etc/init.d/ipsec_start.sh <<EOF
#!/bin/sh

### BEGIN INIT INFO
# Provides:          ipsec
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ipsec start
# Description:       ipsec start
#                    placed in /etc/init.d.
### END INIT INFO

ipsec start
EOF

chmod 777 /etc/init.d/ipsec_start.sh
chmod ugo+x /etc/init.d/ipsec_start.sh
update-rc.d ipsec_start.sh defaults

ipsec restart
ipsec listcerts

echo vpn client cert
cat vpn_certs/server-root-ca.pem

set +x #echo off
echo "check ssh connection, if all ok run commands:"
echo "netfilter-persistent save"
echo "netfilter-persistent reload"
