#!/bin/bash
info()
{
    echo '[INFO] ' "$@"
}

infoL()
{
    echo -en '[INFO] ' "$@\n"
}

sleep_cursor()
{
 chars="/-\|"
 for (( z=0; z<7; z++ )); do
   for (( i=0; i<${#chars}; i++ )); do
    sleep 0.5
    echo -en "${chars:$i:1}" "\r"
  done
done
}


wait() 
{
status=1
infoL "Testing.." $1.$2  
while [ : ]
  do
    sleep_cursor &
    kubectl wait --for condition=available --timeout=14s deploy -l  $1   -n $2
    status=$?
    
    if [ $status -ne 0 ]
    then 
      infoL "$1 isn't ready yet. This may take a few minutes..."
      sleep_cursor
    else
      break  
    fi 
  done
}



curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

info "Installing pipelines crd"
export PIPELINE_VERSION=1.0.1
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=$PIPELINE_VERSION"
kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io
sleep_cursor &
info "Installing pipelines manifests"
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/env/platform-agnostic-pns?ref=$PIPELINE_VERSION"

waiting_pod_array=("k8s-app=kube-dns;kube-system" 
                   "k8s-app=metrics-server;kube-system"
                   "app=traefik;kube-system"  
                   "app=minio;kubeflow"
                   "app=mysql;kubeflow"
                   "app=cache-server;kubeflow"
                   "app=ml-pipeline-persistenceagent;kubeflow"
                   "component=metadata-grpc-server;kubeflow"
                   "app=ml-pipeline-ui;kubeflow")

for i in "${waiting_pod_array[@]}"; do 
  echo "$i"; 
  IFS=';' read -ra VALUES <<< "$i"
    wait "${VALUES[0]}" "${VALUES[1]}"
done


info "Kubeflow pipelines ready!!"

info "Defining the ingress"
sleep_cursor

kubectl apply -f manifests/k3s-ingress/ingress.yaml
sleep_cursor

info "K3s AI ready!!"

info "To use kubectl: export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

IP=$(kubectl get service/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' -n kube-system)
info "pipelines UI: http://"$IP 