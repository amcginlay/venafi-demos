#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

DEMO_PROMPT="${GREEN}➜ ${COLOR_RESET}"
DEMO_CMD_COLOR=$CYAN

# hide the evidence
clear
read -p "↲"

# functions
function end-of-section() {
  read -p "↲" && pei "clear"
}

function delete-all-local-k8s-clusters() {
  printf "\n${PURPLE}# deleting all clusters${COLOR_RESET}\n"
  pei "for cluster in \$(kind get clusters); do kind delete cluster --name \${cluster}; done"
}

export CLUSTER_NAME="k8s-$(date +'%y%m%d%H%M')"
function create-local-k8s-cluster() {
  printf "\n${PURPLE}# creating cluster${COLOR_RESET}\n"
  pei "kind create cluster --name ${CLUSTER_NAME}"
}

function deploy-agent() {
  printf "\n${PURPLE}# registering cluster with Control Plane${COLOR_RESET}\n"
  OWNER=InfoSec # TODO may need to parameterize the owner
  pei "venctl installation cluster connect --name ${CLUSTER_NAME} --kubeconfig-context kind-${CLUSTER_NAME} --owning-team ${OWNER} --no-prompts --api-key \${VCP_APIKEY}"
}

function deploy-components() {
  printf "\n${PURPLE}# apply pull secret, build helmfile manifest and deploy required TLSPK components (~2 mins)${COLOR_RESET}\n"

  # !!! JUST EXECUTE THE FOLLOWING TO HIDE ALL THE JSCTL NASTINESS !!!
  jsctl registry auth output --format secret | yq '.metadata.name = "'"tlspk-operator"'"' | yq '.metadata.namespace = "'"venafi"'"' > ${temp_dir}/pullsecret.yaml
  REGISTRY_USERNAME=$(yq '.data."'".dockerconfigjson"'"' ${temp_dir}/pullsecret.yaml | base64 -d | jq '.auths."'"eu.gcr.io"'".username' -r)
  REGISTRY_PASSWORD=$(yq '.data."'".dockerconfigjson"'"' ${temp_dir}/pullsecret.yaml | base64 -d | jq '.auths."'"eu.gcr.io"'".password' -r)

  kubectl create namespace venafi 2>/dev/null # should already exist, belt and braces
  pei "kubectl apply -f \${temp_dir}/pullsecret.yaml" # in venafi namespace
  pei "export VENAFI_TLSPK_USERNAME=\$REGISTRY_USERNAME VENAFI_TLSPK_PASSWORD=\$REGISTRY_PASSWORD"
  pei "venafi-operator --default-approver --venafi-enhanced-issuer | helmfile sync -f -"
}

function patch-approver-rbac() {
  printf "\n${PURPLE}# cert-manager default approver needs RBAC coverage for VEI resource types${COLOR_RESET}\n"
  pei "cat ven-issuer-rbac-patch.json"
  pei "kubectl -n venafi patch clusterrole cert-manager-controller-approve:cert-manager-io --type=json --patch "'"$(cat ven-issuer-rbac-patch.json)"'""
}

function create-unsafe-tls-secrets() {
  printf "\n${PURPLE}# creating certificate as secret WITHOUT cert-manager${COLOR_RESET}\n"
  pei "export common_name=unsafe.${CLUSTER_NAME}.venafidemo.com"
  pei "cat rogue-certificate-template.conf"

  pei "openssl genrsa -out \${temp_dir}/key.pem 2048" # https://gist.github.com/croxton/ebfb5f3ac143cd86542788f972434c96
  pei "openssl req -new -key \${temp_dir}/key.pem -out \${temp_dir}/csr.pem -subj \"/CN=${common_name}\" -reqexts req_ext -config <(envsubst < rogue-certificate-template.conf)"
  pei "openssl x509 -req -in \${temp_dir}/csr.pem -signkey \${temp_dir}/key.pem -out \${temp_dir}/cert.pem -days 90 -extensions req_ext -extfile <(envsubst < rogue-certificate-template.conf)"
  
  pei "kubectl create namespace demo-certs 2>/dev/null"
  pei "kubectl -n demo-certs create secret tls $(tr '.' '-' <<< ${common_name})-tls --cert=\${temp_dir}/cert.pem --key=\${temp_dir}/key.pem"
}

function store-control-plane-api-key() {
  printf "\n${PURPLE}# create a secret to contain the Control Plane API key${COLOR_RESET}\n"
  kubectl create namespace venafi 2>/dev/null # should already exist, belt and braces
  pei "kubectl -n venafi create secret generic vcp-credentials --from-literal=api-key=\${VCP_APIKEY}"
}

function create-native-issuer() {
  echo && echo "# create a cluster-wide cert-manager issuer able to send CRs to the Control Plane"
  pei "cat ven-native-issuer.yaml"
  pei "kubectl apply -f ven-native-issuer.yaml"
}

function create-vei-issuer() {  
  printf "\n${PURPLE}# create a re-useable Control Plane connection in the venafi namespace${COLOR_RESET}\n"
  pei "cat ven-connection.yaml"
  pei "kubectl -n venafi apply -f ven-connection.yaml"
  # RBAC as per https://platform.jetstack.io/documentation/configuration/venafi-connection/connection/secret (least privilege)
  
  printf "\n${PURPLE}# update the RBAC to allow the venafi-connection service account to read the secret${COLOR_RESET}\n"
  pei "cat ven-connection-rbac.yaml"
  pei "kubectl -n venafi apply -f ven-connection-rbac.yaml"

  printf "\n${PURPLE}# create a cluster-wide cert-manager issuer able to send CRs to the Control Plane${COLOR_RESET}\n"
  pei "cat ven-issuer.yaml"
  pei "kubectl apply -f ven-issuer.yaml"
}

function create-safe-tls-secrets() {
  printf "\n${PURPLE}# creating certificates as secrets WITH cert-manager${COLOR_RESET}\n"
  pei "kubectl create namespace demo-certs 2>/dev/null"
  pei "cat ven-certificate-template.yaml"

  printf "\n${PURPLE}# create VALID cert (venafidemo.com)${COLOR_RESET}\n"
  pei "export common_name=valid.${CLUSTER_NAME}.venafidemo.com"
  pei "export secret_name=valid-${CLUSTER_NAME}-venafidemo-com-tls"
  pei "export duration_hrs=1800" # 75 days
  pei "cat ven-certificate-template.yaml | envsubst | kubectl -n demo-certs apply -f -"

  printf "\n${PURPLE}# create INVALID cert (venafitest.com)${COLOR_RESET}\n"
  pei "export common_name=invalid.${CLUSTER_NAME}.venafitest.com"
  pei "export secret_name=invalid-${CLUSTER_NAME}-venafitest-com-tls"
  pei "export duration_hrs=1140" # 60 days
  pei "cat ven-certificate-template.yaml | envsubst | kubectl -n demo-certs apply -f -"
}

function cluster-info() {
  pei "kubectl cluster-info"
}

function show-namespaces() {
  pei 'kubectl get namespaces' # | grep "demos/\|ingress-nginx/\|cert-manager/\|^" --color'
}

function summary() {
  pei "kubectl -n demos get certificate ${certificate}"
  pei "kubectl -n demos describe secret ${certificate} | tail -4"
  pei "kubectl -n demos get secret ${certificate} -o 'go-template={{index .data \"tls.crt\"}}' | base64 --decode | openssl x509 -noout -text | head -11"
}

# [main] - note in case of DNS resolution failures in curl, disable ipv6 on local machine

temp_dir=$(mktemp -d)

# TODO add the VCert stuff here (or put in a separate script)

delete-all-local-k8s-clusters
create-local-k8s-cluster
end-of-section

deploy-agent
end-of-section

deploy-components
end-of-section

patch-approver-rbac
end-of-section

create-unsafe-tls-secrets
end-of-section

store-control-plane-api-key
end-of-section

# *** using VEI in preference to native - also possible bug where native issuer ignores duration ***
# create-native-issuer
# end-of-section

create-vei-issuer
end-of-section

create-safe-tls-secrets
end-of-section

# cluster-info
# show-namespaces
# end-of-section

# summary

echo "Demo complete!"
