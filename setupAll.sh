#!/bin/sh

user_name=$1
user_pass=$2
strongSwanIP=$3
squidPort=$4
danteInterface=$5
dantePort=$6

if    [ -z ${user_name} ] || [ -z ${user_pass} ]      || [ -z ${strongSwanIP} ]\
   || [ -z ${squidPort} ] || [ -z ${danteInterface} ] || [ -z ${dantePort} ]; then
  echo "Usage: $0 user_name user_pass strongSwanIP squidPort danteInterface dantePort"
  exit 1
fi

set -x #echo on
#apt update
set +x #echo off

sh setupSquid.sh ${squidPort} ${user_name} ${user_pass} noaptupdate
set +x #echo off
sh setupDanteServer.sh ${danteInterface} ${dantePort} ${user_name} ${user_pass} noaptupdate
set +x #echo off
sh setupStrongSwan.sh ${strongSwanIP} ${user_name} ${user_pass} noaptupdate
