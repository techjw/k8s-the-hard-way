#!/usr/bin/env bash
PROJECT=${1:-"k8s"}
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
KEYDIR="${SCRIPTDIR%/*}/keys"

KUBERNETES_PUBIP=$(gcloud compute addresses describe ${PROJECT}-lb-pubip \
  --region $(gcloud config get-value compute/region) --format 'value(address)')

gcloud compute http-health-checks create ${PROJECT}-healthz \
  --description "Kubernetes Health Check" \
  --host "kubernetes.default.svc.cluster.local" \
  --request-path "/healthz"

gcloud compute firewall-rules create ${PROJECT}-allow-health-check \
  --network ${PROJECT}-network --allow tcp \
  --source-ranges 209.85.152.0/22,209.85.204.0/22,35.191.0.0/16 \

gcloud compute target-pools create ${PROJECT}-target-pool \
  --http-health-check ${PROJECT}-healthz

gcloud compute target-pools add-instances ${PROJECT}-target-pool \
 --instances ${PROJECT}-master-0,${PROJECT}-master-1,${PROJECT}-master-2

gcloud compute forwarding-rules create ${PROJECT}-forwarding-rule \
  --address ${KUBERNETES_PUBIP} --ports 6443 \
  --region $(gcloud config get-value compute/region) \
  --target-pool ${PROJECT}-target-pool

echo "Test load balancer functionality via command:"
echo "    curl --cacert ${KEYDIR}/ca.pem https://${KUBERNETES_PUBIP}:6443/version"
