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
function end_of_section() {
  read -p "↲" && pei "clear"
}

function cluster_info() {
  pei "kubectl cluster-info"
}

function show_namespaces() {
  pei 'kubectl get namespaces' # | grep "demos/\|ingress-nginx/\|cert-manager/\|^" --color'
}

function deploy_workload() {
  pei "kubectl create namespace demos"
  pei "kubectl -n demos run demo-app --image amcginlay/test-container:1.0.0 --port 80"
  pei "kubectl -n demos expose pod demo-app --port 8080 --target-port 80"
}

function deploy_ingress_nginx() {
  pei "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update"
  pei "helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace"
}

function deploy_cert_manager() {
  pei "helm repo add jetstack https://charts.jetstack.io && helm repo update"
  pei "helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.10.0 --set installCRDs=true"
}

function verify_ingress_nginx() {
  pei "kubectl -n ingress-nginx get service ingress-nginx-controller"
  pei "aws elb describe-load-balancers --query 'LoadBalancerDescriptions[].DNSName'"
  pei "elb_dnsname=\$(kubectl -n ingress-nginx get service ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
  pei 'until curl -L http://${elb_dnsname} >/dev/null 2>&1; do printf ".";sleep 1;done;echo' # NOTE: "$" not escaped here!
  pei "curl -L http://\${elb_dnsname}"
}

function verify_cert_manager() {
  pei "kubectl -n cert-manager get deploy,svc"
  pei "kubectl api-resources --api-group=cert-manager.io"
}

function create_issuer() {
  pei "cat ./issuer.yaml"
  pei "kubectl -n demos apply -f ./issuer.yaml"
  pei "kubectl -n demos describe issuer letsencrypt | grep Message"
}

function export_dns_record_name() {
  subdomain_ext=${1:-$(date +"%d%H%M")} # arg1 is override
  pei "hosted_zone=jetstack.mcginlay.net" # IMPORTANT - adjust as appropriate
  pei "subdomain_ext=${subdomain_ext}"
  pei "export dns_record_name=www\${subdomain_ext}.\${hosted_zone}"
}

function configure_r53() {
  # depends on export_dns_record_name()
  echo "manual step: add ${dns_record_name} at https://us-east-1.console.aws.amazon.com/route53/v2/hostedzones, then come back here ..."
  # ^^^^ THIS does not have to be a manual step, it just makes the demo feel more "real" ^^^^
}

function verify_r53() {
  # depends on export_dns_record_name()
  pei "echo \${dns_record_name}"
  pei 'until curl -L http://${dns_record_name} >/dev/null 2>&1; do printf ".";sleep 1;done;echo' # NOTE: "$" not escaped here!
  pei "curl -L http://${dns_record_name}"
}

function export_certificate() {
  # depends on export_dns_record_name()
  pei "export certificate=\$(tr \. - <<< \${dns_record_name})-tls"
}

function recap_exported_variables(){
  pei "echo \${dns_record_name}"
  pei "echo \${certificate}"
}

function create_ingress_rule() {
  # depends on export_dns_record_name()
  # depends on export_certificate()
  pei "cat ./ingress.yaml.template"
  end_of_section
  pei "cat ./ingress.yaml.template | envsubst"
  pei "cat ./ingress.yaml.template | envsubst | kubectl apply -n demos -f -"
}

function verify_ingress_rule() {
  # depends on export_dns_record_name()
  pei "kubectl -n demos get ingress demo-ingress"
  pei 'until curl -L https://${dns_record_name} >/dev/null 2>&1; do printf ".";sleep 1;done;echo' # NOTE: "$" not escaped here!
  pei "curl -Ls https://${dns_record_name}"
}

function summary() {
  pei "kubectl -n demos get certificate ${certificate}"
  pei "kubectl -n demos describe secret ${certificate} | tail -4"
  pei "kubectl -n demos get secret ${certificate} -o 'go-template={{index .data \"tls.crt\"}}' | base64 --decode | openssl x509 -noout -text | head -11"
}

# [main] - note in case of DNS resolution failures in curl, disable ipv6 on local machine
cluster_info
show_namespaces
end_of_section

deploy_workload
end_of_section

deploy_ingress_nginx
end_of_section

deploy_cert_manager
end_of_section

show_namespaces
verify_ingress_nginx
end_of_section

verify_cert_manager
end_of_section

create_issuer
end_of_section

export_dns_record_name # <- use arg to override dated subdomain extension
configure_r53
end_of_section

verify_r53
end_of_section

export_certificate
recap_exported_variables
create_ingress_rule
end_of_section

verify_ingress_rule
end_of_section

summary

echo "Demo complete!"
