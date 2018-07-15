#!/usr/bin/env bash
# USAGE: genCerts.sh PROJECT cert-type|all
#   cert-types = admin, kubelet, kube-proxy, kube-controller, kube-scheduler, kube-apiserver, service-account

function gen_admin {
  cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "New York",
      "L": "Troy",
      "O": "system:masters",
      "OU": "kubernetes"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
}

function gen_kubelet {
  for instance in ${PROJECT}-worker-0 ${PROJECT}-worker-1 ${PROJECT}-worker-2; do
    EXTERNAL_IP=$(gcloud compute instances describe ${instance} --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
    INTERNAL_IP=$(gcloud compute instances describe ${instance} --format 'value(networkInterfaces[0].networkIP)')
    cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "New York",
      "L": "Troy",
      "O": "system:nodes",
      "OU": "kubernetes"
    }
  ]
}
EOF

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
      -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
      -profile=kubernetes ${instance}-csr.json | cfssljson -bare ${instance}
  done
}

function gen_kube_proxy {
  cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "New York",
      "L": "Troy",
      "O": "system:node-proxier",
      "OU": "kubernetes"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
    -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
}

function gen_kube_controller {
  cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "New York",
      "L": "Troy",
      "O": "system:kube-controller-manager",
      "OU": "kubernetes"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
    -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
}

function gen_kube_scheduler {
  cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "New York",
      "L": "Troy",
      "O": "system:kube-scheduler",
      "OU": "kubernetes"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
    -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler
}

function gen_kube_apiserver {
  kubernetes_pubip=$(gcloud compute addresses describe ${PROJECT}-lb-pubip \
    --region $(gcloud config get-value compute/region) --format 'value(address)')

  HOSTNAMES="${kubernetes_pubip},10.32.0.1,127.0.0.1,kubernetes.default"
  for instance in ${PROJECT}-master-0 ${PROJECT}-master-1 ${PROJECT}-master-2; do
    extIP=$(gcloud compute instances describe ${instance} --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
    intIP=$(gcloud compute instances describe ${instance} --format 'value(networkInterfaces[0].networkIP)')
    HOSTNAMES="${intIP},${extIP},${HOSTNAMES}"
  done

  cat > kubernetes-csr.json <<EOF
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
      "O": "kubernetes",
      "OU": "kubernetes"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
    -hostname=${HOSTNAMES} -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
}

function gen_service_account {
  cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "New York",
      "L": "Troy",
      "O": "Kubernetes",
      "OU": "kubernetes"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
    -profile=kubernetes service-account-csr.json | cfssljson -bare service-account
}

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="${SCRIPTDIR%/*}"
KEYDIR="${BASEDIR}/keys"

mkdir -p $KEYDIR
cd $KEYDIR

PROJECT=${1:-"k8s"}
case $2 in
  "admin") gen_admin ;;
  "kubelet") gen_kubelet ;;
  "kube-proxy") gen_kube_proxy ;;
  "kube-controller") gen_kube_controller ;;
  "kube-scheduler") gen_kube_scheduler ;;
  "kube-apiserver") gen_kube_apiserver ;;
  "service-account") gen_service_account ;;
  "all")
    gen_admin
    gen_kubelet
    gen_kube_proxy
    gen_kube_controller
    gen_kube_scheduler
    gen_kube_apiserver
    gen_service_account
  ;;
  *) echo "ERROR: unknown certificate specified ($2)" && exit 1 ;;
esac
