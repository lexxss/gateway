#!/bin/sh

interface=$1
port=$2
user_name=$3
user_pass=$4
noaptupdate=$5

if [ -z ${interface} ] || [ -z ${port} ] || [ -z ${user_name} ] || [ -z ${user_pass} ]; then
        echo "Usage: $0 interface port user_name user_pass [noaptupdate]"
        exit 1
fi

set -x #echo on

if [ -z ${noaptupdate} ] || [ ${noaptupdate} != "noaptupdate" ]; then
  apt update
fi

apt -y install dante-server

cat > /etc/danted.conf <<EOF
# $Id: sockd.conf,v 1.43 2005/12/26 16:35:26 michaels Exp $
#
# A sample danted.conf
#
#
# The configfile is divided into three parts;
#    1) serversettings
#    2) rules
#    3) routes
#
# The recommended order is:
#   Serversettings:
#               logoutput
#               internal
#               external
#               method
#               clientmethod
#               users
#               compatibility
#               extension
#               connecttimeout
#               iotimeout
#               srchost
#
#  Rules:
#       client block/pass
#               from to
#               libwrap
#               log
#
#     block/pass
#               from to
#               method
#               command
#               libwrap
#               log
#               protocol
#               proxyprotocol
#
#  Routes:

# the server will log both via syslog, to stdout and to /var/log/lotsoflogs
#logoutput: syslog stdout /var/log/lotsoflogs
logoutput: syslog stdout /var/log/sockd.log

# The server will bind to the address 10.1.1.1, port 1080 and will only
# accept connections going to that address.
#internal: 10.1.1.1 port = 1080
# Alternatively, the interface name can be used instead of the address.
#ch###################################################################################################
internal: ${interface} port = ${port}

# all outgoing connections from the server will use the IP address
# 195.168.1.1
#ch###################################################################################################
external: ${interface}

# list over acceptable methods, order of preference.
# A method not set here will never be selected.
#
# If the method field is not set in a rule, the global
# method is filled in for that rule.
#

# methods for socks-rules.
#ch###################################################################################################
socksmethod: username

# methods for client-rules.
#clientmethod: username

#or if you want to allow rfc931 (ident) too
#method: username rfc931 none

#or for PAM authentification
#method: pam

#
# An important section, pay attention.
#

# when doing something that can require privilege, it will use the
# userid:
#ch###################################################################################################
user.privileged: root

# when running as usual, it will use the unprivileged userid of:
user.notprivileged: nobody

#ch###################################################################################################
client pass {
       from: 0.0.0.0/0 to: 0.0.0.0/0
}

#ch###################################################################################################
socks pass {
       from: 0.0.0.0/0 to: 0.0.0.0/0
}

# If you compiled with libwrap support, what userid should it use
# when executing your libwrap commands?  "libwrap".
# user.libwrap: nobody


#
# some options to help clients with compatibility:
#

# when a client connection comes in the socksserver will try to use
# the same port as the client is using, when the socksserver
# goes out on the clients behalf (external: IP address).
# If this option is set, Dante will try to do it for reserved ports aswell.
# This will usually require user.privileged to be set to "root".
#compatibility: sameport

# If you are using the bind extension and have trouble running servers
# via the server, you might try setting this.  The consequences of it
# are unknown.
#compatibility: reuseaddr

#
# The Dante server supports some extensions to the socks protocol.
# These require that the socks client implements the same extension and
# can be enabled using the "extension" keyword.
#
# enable the bind extension.
#extension: bind


#
#
# misc options.
#

# how many seconds can pass from when a client connects til it has
# sent us it's request?  Adjust according to your network performance
# and methods supported.
#connecttimeout: 30   # on a lan, this should be enough if method is "none".

# how many seconds can the client and it's peer idle without sending
# any data before we dump it?  Unless you disable tcp keep-alive for
# some reason, it's probably best to set this to 0, which is
# "forever".
#iotimeout: 0 # or perhaps 86400, for a day.

# do you want to accept connections from addresses without
# dns info?  what about addresses having a mismatch in dnsinfo?
#srchost: nounknown nomismatch

#
# The actual rules.  There are two kinds and they work at different levels.
#
# The rules prefixed with "client" are checked first and say who is allowed
# and who is not allowed to speak/connect to the server.  I.e the
# ip range containing possibly valid clients.
# It is especially important that these only use IP addresses, not hostnames,
# for security reasons.
#
# The rules that do not have a "client" prefix are checked later, when the
# client has sent its request and are used to evaluate the actual
# request.
#
# The "to:" in the "client" context gives the address the connection
# is accepted on, i.e the address the socksserver is listening on, or
# just "0.0.0.0/0" for any address the server is listening on.
#
# The "to:" in the non-"client" context gives the destination of the clients
# socksrequest.
#
# "from:" is the source address in both contexts.
#


# the "client" rules.  All our clients come from the net 10.0.0.0/8.
#

# Allow our clients, also provides an example of the port range command.
#client pass {
#       from: 10.0.0.0/8 port 1-65535 to: 0.0.0.0/0
#       method: rfc931 # match all idented users that also are in passwordfile
#}

# This is identical to above, but allows clients without a rfc931 (ident)
# too.  In practise this means the socksserver will try to get a rfc931
# reply first (the above rule), if that fails, it tries this rule.
#client pass {
#       from: 0.0.0.0/0 to: 0.0.0.0/0
#}


# drop everyone else as soon as we can and log the connect, they are not
# on our net and have no business connecting to us.  This is the default
# but if you give the rule yourself, you can specify details.
#client block {
#       from: 0.0.0.0/0 to: 0.0.0.0/0
#       log: connect error
#}


# the rules controlling what clients are allowed what requests
#

# you probably don't want people connecting to loopback addresses,
# who knows what could happen then.
#block {
#       from: 0.0.0.0/0 to: 127.0.0.0/8
#       log: connect error
#}

# the people at the 172.16.0.0/12 are bad, no one should talk to them.
# log the connect request and also provide an example on how to
# interact with libwrap.
#block {
#       from: 0.0.0.0/0 to: 172.16.0.0/12
#       libwrap: spawn finger @%a
#       log: connect error
#}

# unless you need it, you could block any bind requests.
#block {
#       from: 0.0.0.0/0 to: 0.0.0.0/0
#       command: bind
#       log: connect error
#}

# or you might want to allow it, for instance "active" ftp uses it.
# Note that a "bindreply" command must also be allowed, it
# should usually by from "0.0.0.0/0", i.e if a client of yours
# has permission to bind, it will also have permission to accept
# the reply from anywhere.
#pass {
#       from: 10.0.0.0/8 to: 0.0.0.0/0
#       command: bind
#       log: connect error
#}

# some connections expect some sort of "reply", this might be
# the reply to a bind request or it may be the reply to a
# udppacket, since udp is packetbased.
# Note that nothing is done to verify that it's a "genuine" reply,
# that is in general not possible anyway.  The below will allow
# all "replies" in to your clients at the 10.0.0.0/8 net.
#pass {
#       from: 0.0.0.0/0 to: 10.0.0.0/8
#       command: bindreply udpreply
#       log: connect error
#}


# pass any http connects to the example.com domain if they
# authenticate with username.
# This matches "example.com" itself and everything ending in ".example.com".
#pass {
#       from: 0.0.0.0/0 to: 0.0.0.0/0
#}


# block any other http connects to the example.com domain.
#block {
#       from: 0.0.0.0/0 to: .example.com port = http
#       log: connect error
#}

# everyone from our internal network, 10.0.0.0/8 is allowed to use
# tcp and udp for everything else.
#pass {
#       from: 10.0.0.0/8 to: 0.0.0.0/0
#       protocol: tcp udp
#}

# last line, block everyone else.  This is the default but if you provide
# one  yourself you can specify your own logging/actions
#block {
#       from: 0.0.0.0/0 to: 0.0.0.0/0
#       log: connect error
#}

# route all http connects via an upstream socks server, aka "server-chaining".
#route {
# from: 10.0.0.0/8 to: 0.0.0.0/0 port = http via: socks.example.net port = socks
#}
EOF

useradd --shell /usr/sbin/nologin -p $(openssl passwd -1 ${user_pass}) ${user_name}
systemctl restart danted
systemctl enable danted

systemd_override_folder=/etc/systemd/system/danted.service.d
systemd_override_conf=${systemd_override_folder}/override.conf

mkdir -p ${systemd_override_folder}

cat > ${systemd_override_conf} <<EOF
[Service]
ExecStartPost=/bin/sleep 0.2
Restart=always
EOF

systemctl daemon-reload
systemctl restart danted
