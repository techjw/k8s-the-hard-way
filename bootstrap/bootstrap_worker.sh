#!/usr/bin/env bash

PROJECT=${1:-"k8s"}
CLUSTER_CIDR=${2:-"10.200.0.0/20"}
SERVICE_CIDR=${3:-"10.32.0.0/24"}

##### Setup Docker #####
sudo apt-get update
sudo apt-get install -q -y apt-transport-https

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt-get update
sudo apt-get install -q -y docker-ce=18.03.1~ce~3-0~ubuntu

cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "storage-opts":[],
  "log-driver": "json-file",
  "log-opts": {
    "max-file": "1",
    "max-size": "100m"
  }
}
EOF

##### Download binaries #####
curl -OL https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz
for kube in kube-proxy kubelet kubectl ; do
  curl -OL "https://storage.googleapis.com/kubernetes-release/release/v1.10.5/bin/linux/amd64/${kube}"
  chmod +x $kube
  sudo mv $kube /usr/local/bin/
done

##### Create directories #####
sudo mkdir -p /etc/cni/net.d /opt/cni/bin /etc/weave \
  /var/lib/kubelet /var/lib/kube-proxy \
  /var/lib/kubernetes /var/run/kubernetes \
  /etc/kubernetes/manifests

##### Pull metadata info #####
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)

##### Install common CNI plugins #####
sudo tar -zxf cni-plugins-amd64-v0.7.1.tgz -C /opt/cni/bin/

##### Setup Weave configuration files #####
cat <<EOF | sudo tee /etc/cni/net.d/00-weave.conflist
{
    "cniVersion": "0.3.0",
    "name": "mynet",
      "plugins": [
        {
            "name": "weave",
            "type": "weave-net",
            "hairpinMode": true
        },
        {
            "type": "portmap",
            "capabilities": {"portMappings": true},
            "snat": true
        }
    ]
}
EOF

cat <<EOF |sudo tee /etc/weave/weave.yaml
apiVersion: v1
kind: List
items:
  - apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: weave-net
      labels:
        tier: control-plane
        name: weave-net
      namespace: kube-system
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: weave-net
      labels:
        tier: control-plane
        name: weave-net
    rules:
      - apiGroups:
          - ''
        resources:
          - pods
          - namespaces
          - nodes
        verbs:
          - get
          - list
          - watch
      - apiGroups:
          - networking.k8s.io
        resources:
          - networkpolicies
        verbs:
          - get
          - list
          - watch
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: weave-net
      labels:
        tier: control-plane
        name: weave-net
    roleRef:
      kind: ClusterRole
      name: weave-net
      apiGroup: rbac.authorization.k8s.io
    subjects:
      - kind: ServiceAccount
        name: weave-net
        namespace: kube-system
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: weave-net
      annotations:
      labels:
        name: weave-net
      namespace: kube-system
    rules:
      - apiGroups:
          - ''
        resourceNames:
          - weave-net
        resources:
          - configmaps
        verbs:
          - get
          - update
      - apiGroups:
          - ''
        resources:
          - configmaps
        verbs:
          - create
  - apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: weave-net
      annotations:
      labels:
        name: weave-net
      namespace: kube-system
    roleRef:
      kind: Role
      name: weave-net
      apiGroup: rbac.authorization.k8s.io
    subjects:
      - kind: ServiceAccount
        name: weave-net
        namespace: kube-system
  - apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: weave-net
      labels:
        tier: control-plane
        name: weave-net
        k8s-app: weave-net
      namespace: kube-system
    spec:
      selector:
        matchLabels:
          k8s-app: weave-net
      minReadySeconds: 5
      template:
        metadata:
          labels:
            name: weave-net
            k8s-app: weave-net
          annotations:
            scheduler.alpha.kubernetes.io/critical-pod: ''
        spec:
          containers:
            - name: weave
              command:
                - /home/weave/launch.sh
              env:
                - name: HOSTNAME
                  valueFrom:
                    fieldRef:
                      apiVersion: v1
                      fieldPath: spec.nodeName
                - name: IPALLOC_RANGE
                  value: "${CLUSTER_CIDR}"
                - name: WEAVE_PASSWORD
                  value: ''
              image: 'weaveworks/weave-kube:2.3.0'
              imagePullPolicy: IfNotPresent
              livenessProbe:
                httpGet:
                  host: 127.0.0.1
                  path: /status
                  port: 6784
                initialDelaySeconds: 30
              resources:
                requests:
                  cpu: 10m
              securityContext:
                privileged: true
              volumeMounts:
                - name: weavedb
                  mountPath: /weavedb
                - name: cni-bin
                  mountPath: /host/opt
                - name: cni-bin2
                  mountPath: /host/home
                - name: cni-conf
                  mountPath: /host/etc
                - name: dbus
                  mountPath: /host/var/lib/dbus
                - name: lib-modules
                  mountPath: /lib/modules
                - name: xtables-lock
                  mountPath: /run/xtables.lock
            - name: weave-npc
              env:
                - name: HOSTNAME
                  valueFrom:
                    fieldRef:
                      apiVersion: v1
                      fieldPath: spec.nodeName
              image: 'weaveworks/weave-npc:2.3.0'
              imagePullPolicy: IfNotPresent
              resources:
                requests:
                  cpu: 10m
              securityContext:
                privileged: true
              volumeMounts:
                - name: xtables-lock
                  mountPath: /run/xtables.lock
          hostNetwork: true
          hostPID: true
          restartPolicy: Always
          securityContext:
            seLinuxOptions: {}
          serviceAccountName: weave-net
          tolerations:
            - effect: NoSchedule
              operator: Exists
          volumes:
            - name: weavedb
              hostPath:
                path: /var/lib/weave
            - name: cni-bin
              hostPath:
                path: /opt
            - name: cni-bin2
              hostPath:
                path: /home
            - name: cni-conf
              hostPath:
                path: /etc
            - name: dbus
              hostPath:
                path: /var/lib/dbus
            - name: lib-modules
              hostPath:
                path: /lib/modules
            - name: xtables-lock
              hostPath:
                path: /run/xtables.lock
EOF

##### Setup Kubelet #####
sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo mv ca.pem /var/lib/kubernetes/

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
eventRecordQPS: 0
makeIPTablesUtilChains: true
podCIDR: "${POD_CIDR}"
readOnlyPort: 0
runtimeRequestTimeout: "15m"
serializeImagePulls: false
staticPodPath: "/etc/kubernetes/manifests"
streamingConnectionIdleTimeout: "0"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --cadvisor-port=0 \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=docker \\
  --docker-endpoint=unix:///var/run/docker.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --node-ip=${INTERNAL_IP} \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

##### Setup kube-proxy #####
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${CLUSTER_CIDR}"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

##### Start/restart and enable services #####
sudo systemctl daemon-reload
sudo systemctl enable docker kubelet kube-proxy
sudo systemctl restart docker
sudo systemctl start kubelet kube-proxy
