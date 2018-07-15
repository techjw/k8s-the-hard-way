#!/usr/bin/env bash
# USAGE: genCerts.sh PROJECT cert-type|all
#   cert-types = admin, kubelet, kube-proxy, kube-controller, kube-scheduler, kube-apiserver, service-account

function gen_admin_cfg {
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${KEYDIR}/ca.pem --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=${KEYDIR}/admin.pem --client-key=${KEYDIR}/admin-key.pem \
    --embed-certs=true --kubeconfig=admin.kubeconfig

  kubectl config set-context default --cluster=kubernetes-the-hard-way \
    --user=admin --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}

function gen_kubelet_cfg {
  for instance in ${PROJECT}-worker-0 ${PROJECT}-worker-1 ${PROJECT}-worker-2; do
    kubectl config set-cluster kubernetes-the-hard-way \
      --certificate-authority=${KEYDIR}/ca.pem --embed-certs=true \
      --server=https://${KUBERNETES_PUBIP}:6443 \
      --kubeconfig=${instance}.kubeconfig

    kubectl config set-credentials system:node:${instance} \
      --client-certificate=${KEYDIR}/${instance}.pem --client-key=${KEYDIR}/${instance}-key.pem \
      --embed-certs=true --kubeconfig=${instance}.kubeconfig

    kubectl config set-context default --cluster=kubernetes-the-hard-way \
      --user=system:node:${instance} --kubeconfig=${instance}.kubeconfig

    kubectl config use-context default --kubeconfig=${instance}.kubeconfig
  done
}

function gen_kube_proxy_cfg {
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${KEYDIR}/ca.pem --embed-certs=true \
    --server=https://${KUBERNETES_PUBIP}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=${KEYDIR}/kube-proxy.pem --client-key=${KEYDIR}/kube-proxy-key.pem \
    --embed-certs=true --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}

function gen_kube_controller_cfg {
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${KEYDIR}/ca.pem --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=${KEYDIR}/kube-controller-manager.pem --client-key=${KEYDIR}/kube-controller-manager-key.pem \
    --embed-certs=true --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}

function gen_kube_scheduler_cfg {
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${KEYDIR}/ca.pem --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=${KEYDIR}/kube-scheduler.pem --client-key=${KEYDIR}/kube-scheduler-key.pem \
    --embed-certs=true --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}

function gen_encryption_cfg {
  ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
  cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
}


SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="${SCRIPTDIR%/*}"
KEYDIR="${BASEDIR}/keys"
CFGDIR="${BASEDIR}/configs"

mkdir -p $CFGDIR
cd $CFGDIR

PROJECT=${1:-"k8s"}
KUBERNETES_PUBIP=$(gcloud compute addresses describe ${PROJECT}-lb-pubip \
  --region $(gcloud config get-value compute/region) --format 'value(address)')

case $2 in
  "admin") gen_admin_cfg ;;
  "kubelet") gen_kubelet_cfg ;;
  "kube-proxy") gen_kube_proxy_cfg ;;
  "kube-controller") gen_kube_controller_cfg ;;
  "kube-scheduler") gen_kube_scheduler_cfg ;;
  "encryption") gen_encryption_cfg ;;
  "all")
    gen_admin_cfg
    gen_kubelet_cfg
    gen_kube_proxy_cfg
    gen_kube_controller_cfg
    gen_kube_scheduler_cfg
    gen_encryption_cfg
  ;;
  *) echo "ERROR: unknown kubeconfig specified ($2)" && exit 1 ;;
esac
