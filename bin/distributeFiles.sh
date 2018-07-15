#!/usr/bin/env bash
PROJECT=${1:-"k8s"}


SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="${SCRIPTDIR%/*}"
KEYDIR="${BASEDIR}/keys"
CFGDIR="${BASEDIR}/configs"


# Copy client certificates and private keys to worker instances:
for instance in ${PROJECT}-worker-0 ${PROJECT}-worker-1 ${PROJECT}-worker-2; do
  cd $KEYDIR && gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
  cd $CFGDIR && gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done

# Copy the certificates and private keys to each master instance:
for instance in ${PROJECT}-master-0 ${PROJECT}-master-1 ${PROJECT}-master-2; do
  cd $KEYDIR && gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem ${instance}:~/
  cd $CFGDIR && gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig encryption-config.yaml ${instance}:~/
done
