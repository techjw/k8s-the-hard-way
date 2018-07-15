#!/usr/bin/env bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="${SCRIPTDIR%/*}"
KEYDIR="${BASEDIR}/keys"

mkdir -p $KEYDIR
cd $KEYDIR

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "26280h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "26280h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "New York",
      "L": "Troy",
      "O": "Apprenda",
      "OU": "Client Services"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
