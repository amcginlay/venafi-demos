#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

DEMO_PROMPT="${GREEN}➜ ${COLOR_RESET}"
DEMO_CMD_COLOR=$CYAN

# functions
function manual_step() {
  echo "MANUAL STEP: $1 ..."
  read -p "↲"
}

function end_of_section() {
  read -p "↲" && pei "clear"
}

function check_status() {
  pei "oc status"
}

function check_console_uri() {
  pei "oc -n openshift-console get routes console -o=jsonpath=\"{range}{'https://'}{.spec.host}{end}\""
  echo
}

patch_operatorhub() {
  pei "oc patch OperatorHub cluster --type json -p '[{\"op\": \"add\", \"path\": \"/spec/disableAllDefaultSources\", \"value\": false}]'"
}

patch_nginx_sa() {
  pei "oc -n nginx-ingress adm policy add-scc-to-user -z nginx-ingress anyuid"
  pei "oc -n nginx-ingress adm policy add-scc-to-user -z nginx-ingress privileged"
}

function verify_ingress_nginx() {
  pei "elb_dnsname=\$(oc -n nginx-ingress get service nginxingress-sample-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
  pei "echo \${elb_dnsname}"
  printf "waiting ." && until curl -L http://${elb_dnsname} >/dev/null 2>&1; do printf ".";sleep 1;done;echo
  pei "curl -L http://\${elb_dnsname}"
}

function export_dns_record_name() {
  subdomain_ext=${1:-$(date +"%d")} # arg1 is override
  pei "hosted_zone=venafi.mcginlay.net" # IMPORTANT - adjust as appropriate
  pei "subdomain_ext=${subdomain_ext}"
  pei "export DNS_RECORD_NAME=www\${subdomain_ext}.\${hosted_zone}"
}

function configure_r53() {
  # depends on export_dns_record_name()
  manual_step "Go to Route53 [https://us-east-1.console.aws.amazon.com/route53/v2/hostedzones]. ALIAS required between DNS record ${DNS_RECORD_NAME} and ELB ${elb_dnsname}"
  # ^^^^ THIS does not have to be a manual step, it just makes the demo feel more "real" ^^^^
}

function verify_r53() {
  # depends on export_dns_record_name()
  printf "waiting ." && until curl -L http://${DNS_RECORD_NAME} >/dev/null 2>&1; do printf ".";sleep 1;done;echo
  pei "curl -L http://${DNS_RECORD_NAME}"
}

function verify_cert_manager() {
  pei "oc api-resources --api-group=cert-manager.io"
}

function create_issuer() {
  pei "cat clusterissuer.yaml.template"
  pei "export EMAIL=jbloggs@gmail.com # <-- change this to suit"
  pei "envsubst < clusterissuer.yaml.template | oc apply -f -"
}

function verify_issuer() {
  pei "oc describe clusterissuer letsencrypt | grep Message"
}

function deploy_workload() {
  pei "oc new-project demos"
  pei "oc new-app https://github.com/amcginlay/openshift-test"
}

function create_ingress_rule() {
  # depends on export_dns_record_name()
  pei "cat ingress.yaml.template"
  pei "echo \${DNS_RECORD_NAME}"
  pei "export TLS_SECRET=$(tr \. - <<< ${DNS_RECORD_NAME})-tls"
  pei "envsubst < ingress.yaml.template | oc -n demos apply -f -"
  pei "sleep 2 # NGINX adjusting ..."
}

function verify_ingress_rule() {
  # depends on export_dns_record_name()
  pei "oc -n demos get ingress openshift-test"
  printf "waiting ." && until curl -L https://${DNS_RECORD_NAME} >/dev/null 2>&1; do printf ".";sleep 1;done;echo
  pei "curl -Ls https://${DNS_RECORD_NAME}"
}

function summary() {
  # depends on TLS_SECRET
  pei "oc -n demos get certificate ${TLS_SECRET}"
  pei "oc -n demos describe secret ${TLS_SECRET} | tail -4"
  pei "oc -n demos get secret ${TLS_SECRET} -o 'go-template={{index .data \"tls.crt\"}}' | base64 --decode | openssl x509 -noout -text | head -11"
}

# [main] - note in case of DNS resolution failures in curl, disable ipv6 on local machine
clear
read -p "↲"

check_status
end_of_section

patch_operatorhub
end_of_section

check_console_uri
end_of_section

manual_step "Install NGINX Ingress Operator (watch)"
patch_nginx_sa
manual_step "Deploy NGINX Ingress Controller instance (watch)"
verify_ingress_nginx
end_of_section

export_dns_record_name # <- use arg to override dated subdomain extension
configure_r53
verify_r53
end_of_section

manual_step "Deploy cert-manager (watch)"
verify_cert_manager
end_of_section

create_issuer
verify_issuer
end_of_section

deploy_workload
end_of_section

create_ingress_rule
verify_ingress_rule
end_of_section

summary

echo "Demo complete!"
