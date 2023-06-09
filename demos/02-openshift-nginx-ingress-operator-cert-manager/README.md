# OpenShift with NGINX Ingress Operator and cert-manager

This demo attempts to answer a question you may encounter in the enterprise.

Specifically, if you're using AWS, OpenShift, NGINX Ingress and cert-manager, what are the minimum steps required to secure a public-facing workload?

[![How to Secure Public-Facing Workloads in AWS with OpenShift & cert-manager](https://img.youtube.com/vi/M5zCy-s-Lwk/0.jpg)](https://www.youtube.com/watch?v=M5zCy-s-Lwk)

## Introduction
Your goal here is to enforce secure TLS communication between any browser on the internet and a single containerized workload running in an OpenShift cluster hosted on AWS.
<!-- Much like regular Kubernetes clusters hosted on public cloud providers, OpenShift supports safely exposing your workloads to the internet via load balancers. -->

In this scenario, your browser will expect HTTPS (which implies TLS) but your workload only supports HTTP.

We can implement a reverse proxy solution by positioning an NGINX instance between an internet-facing load balancer (AWS ELB) and the HTTP workload.
The NGINX instance can then be loaded with publicly trusted X.509 certificates, making it responsible for TLS termination.
To clarify, this means traffic touching the internet is HTTPS whilst traffic touching the workload is plain old HTTP.

Instead of having to edit NGINX routing configuration files by hand, NGINX Ingress controllers do this for you by reacting to the presence of Kubernetes Ingress objects.
Those Ingress objects can reference certificates stored as [TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets) in Kubernetes.
On their own, Ingress Controllers are unable to create or renew these certificates.
That's where cert-manager and Let's Encrypt come in.

## Your goal
The following diagram aims to illustrate the goal of this exercise.

![title](images/nginx-tls-os.png)

## Prerequisites
- The necessary client tools installed
- Access to a running OpenShift cluster via `oc` and the console
- Full control of your own domain (or subdomain) surfaced as a **hosted zone** in AWS Route53.

These instructions depend upon content from this directory so `git clone` this repo and `cd` as appropriate.

### Check CLI/console connectivity
Check connectivity via the **CLI**, navigate to the **Console** URL produced and login as `kubeadmin`.
```
oc status
oc -n openshift-console get routes console -o=jsonpath="{range}{'https://'}{.spec.host}{'\n'}{end}"
```

## The OpenShift OperatorHub
OperatorHub is the web console interface that OpenShift administrators use to enable extended capabilities.

The OperatorHub is available here https://your-console/operatorhub/all-namespaces

**Note** some OperatorHub sources may not be available by default so run this patch command to ensure your library is fully stocked.
```
oc patch OperatorHub cluster --type json \
  -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": false}]'
```

## Install NGINX Ingress Operator
From the **OperatorHub**.
- Search for "nginx ingress" then click the "NGINX Ingress Operator" tile
- Click "Install", accept all default settings and click "Install" once more.

If you wish to watch the NGINX Ingress workloads and services as they come online, set up a watch command with the CLI as follows.
```
watch oc -n nginx-ingress get pod,svc
```

## Deploy NGINX Ingress Controller instance

When installing NGINX Ingress via the OperatorHub **you do not immediately get an Ingress Controller instance**, just the means to deploy one.
OpenShift employs a strict security posture which, by default, would prevent you from completing the deployment.

The following command will address this restriction.
```
oc -n nginx-ingress adm policy add-scc-to-user -z nginx-ingress anyuid
oc -n nginx-ingress adm policy add-scc-to-user -z nginx-ingress privileged
```

Now you can successfully deploy your NGINX Ingress Controller instance.

From the **OperatorHub**.
- In the console's navigaton panel, under "Operators", select "Installed Operators"
- Ensure that the "Project" dropdown reads "All Projects"
- Locate the "Nginx Ingress Operator" entry and, under the column named "Provided APIs", click "Nginx Ingress Controller"
- Click "Create NginxIngress"
- Select YAML view
- At about line 31 in the YAML manifest, you should see `secret: nginx-ingress/default-server-secret` (see NOTE below)
- You should **remove this line** to ensure a successful installation
- Click "Create"

NOTE in the interests of simplicity, these instructions omit the pre-provision of the `default-server-secret`, instead choosing to focus on securing specific routes.

Your previous `watch` command will reveal additional workloads and services as your NGINX Ingress Controller instance comes online.
You will observe your new service object is of type **LoadBalancer**, with the EXTERNAL-IP column identifying the associated AWS load balancer.

After 2-3 mins the load balancer will begin returning "404 Not Found" responses.
This is the expected response since no Ingress rules have been applied to NGINX yet.
```
elb_dnsname=$(oc -n nginx-ingress get service nginxingress-sample-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -L http://${elb_dnsname}
```

Wait for a response from the load balancer before continuing.

## Configure Route53

NOTE if you wish to complete this section using the AWS CLI, check out the necessary steps detailed in the [addendum](./addendum/README.md).

To pair your own web domain with an AWS load balancer you will need full control of the appropriate **hosted zone** in a public DNS service.
These instructions assume that service is AWS Route53.

The following section details the assignment of a new Route53 ALIAS record to your domain (or subdomain) which can route traffic to the load balancer you created previously.

NOTE using day of the month in the DNS record (below) is a simplistic way to test out your solution using **production-strength** certificates whilst navigating the CA's [Duplicate Certificate Limit](https://letsencrypt.org/docs/duplicate-certificate-limit/).

Start by setting variables to represent the DNS record name you wish to target.
```bash
hosted_zone=venafi.mcginlay.net   # IMPORTANT - adjust as appropriate
record_subdomain_name=www$(date +"%d") # e.g. www01 - where the digits indicate the day of the month (for testing)
export DNS_RECORD_NAME=${record_subdomain_name}.${hosted_zone}
echo "MANUAL STEP: Route53 ALIAS required between DNS record ${DNS_RECORD_NAME} and ELB ${elb_dnsname}"
```

Head over to https://console.aws.amazon.com/route53/v2/hostedzones and create your new DNS record in your hosted zone as shown below.

![title](images/route53.png)

Once the DNS record has propagated, the new endpoint will also respond with the familiar "404" status page from NGINX.
Wait for this to happen before continuing.
```bash
curl -L http://${DNS_RECORD_NAME}
```

## Your goal (checkpoint 1)
The following diagram illustrates your progress towards the goal of this exercise.

![title](images/nginx-tls-os-partial-1.png)

## Install cert-manager
From the **OperatorHub**.
- Search for "cert-manager" then click the "cert-manager (Community)" tile
- "Continue" past any warnings, click "Install", accept all default settings and click "Install" once more.

If you wish to watch the cert-manager workloads and services as they come online, set up a watch command with the CLI as follows.
```
watch oc -n openshift-operators get pod,svc
```

The OperatorHub install of cert-manager does not require any patching and automatically deploys the required workloads.

## Create Let's Encrypt (ACME) issuer
cert-manager is unable to oversee the creation of any certificates until you have at least one Issuer in place.
The simplest way to create the publicly trusted certificates you require is via [Let's Encrypt](https://letsencrypt.org/), so go ahead and set up a cluster-wide issuer for that.
```
cat clusterissuer.yaml.template
export EMAIL=jbloggs@gmail.com # <-- change this to suit
envsubst < clusterissuer.yaml.template  | oc apply -f -
```

Check on the status of the issuer after you've created it
```bash
oc describe clusterissuer letsencrypt | grep Message
```

## Deploy app
One major difference between opinionated platforms like OpenShift and regular Kubernetes is the way they handle container images.
Kubernetes insists upon consuming ready-made container images whereas OpenShift typically builds container images directly from source code as part of its deployment process.

To build and deploy a demo application which you will go on to secure, run the following.
```
oc new-project demos
oc new-app https://github.com/amcginlay/openshift-test
```

You can watch your app progress to "deployed" status as follows.
```
watch oc status
```

**Note** `oc new-app` automatically attaches a ClusterIP service to your workload.
The next logical step is often documented as `oc expose` which would creates a route to your workload via the Openshift's "default" Ingress Controller.
These instructions omit that step since your goal is to surface the app via an NGINX Ingress Controller.
That goal is achieved with an Ingress rule as described in your next and final step.

## Your goal (checkpoint 2)
The following diagram illustrates your progress towards the goal of this exercise.

![title](images/nginx-tls-os-partial-2.png)

## Creating an Ingress rule

As mentioned, your NGINX Ingress Controller instance is not currently loaded with any routing rules, hence the "404" responses we currently see via the load balancer.
Outside the world of OpenShift and Kubernetes, "vanilla" NGINX would source its rules from a config file (`nginx.conf`).
NGINX Ingress Controller instances works the same, except the controller component ingests Ingress objects and codifies them into config file modifications on your behalf.

As you create your first Ingress object, observe the use of the `ingressClassName` attribute which associates your Ingress rule with a specific variant of Ingress controller (`nginx`), and the `cert-manager.io/issuer` annotation which associates your rule with your Issuer object (`letsencrypt`).
```bash
cat ingress.yaml.template
echo ${DNS_RECORD_NAME}
export TLS_SECRET=$(tr \. - <<< ${DNS_RECORD_NAME})-tls
envsubst < ingress.yaml.template  | oc -n demos apply -f -
```

You can observe your Ingress object as follows.
Note that this supports traffic on port 443 (HTTPS).
```bash
oc -n demos get ingress openshift-test
```

Your ELB will now **securely** route all traffic via HTTPS to your demo workload.
```bash
curl -Ls https://${DNS_RECORD_NAME}
```

At this point you can navigate to the `${DNS_RECORD_NAME}` URL in any browser and you will see padlock icons without warnings.
This means your workload is protected by a publicly trusted X.509 certificate.
By observing the output you can also determine that the request your workload received was plain old HTTP.
This means NGINX done its job - it has routed traffic from the ELB to your workload whilst providing a transparent termination point for the TLS encryption.

## Goal complete (recap)
All the elements of the diagram are now in place.

![title](images/nginx-tls-os.png)

## So, what just happened?

cert-manager is aware of annotated Ingress objects.

It deduced from your Ingress object that traffic to `openshift-test` is intended to be secured by Let's Encrypt so it silently built a cert-manager Certificate object to represent that requirement.
The presence of that Certificate object triggered a sequence of events which resulted in a matching TLS Secret, signed by Let's Encrypt, to be deposited in the demos namespace.

You can view the Certificate and Secret pairs as follows.
```bash
oc -n demos get certificate ${certificate}
oc -n demos describe secret ${certificate} | tail -4
```

The data items in the Secret are base64 encoded.
If you wish, you can use OpenSSL to see the certificate material in its more natural form.
```bash
oc -n demos get secret ${certificate} -o 'go-template={{index .data "tls.crt"}}' | base64 --decode | openssl x509 -noout -text | head -11
```

As expected, your NGINX Ingress Controller instance is also aware of Ingress objects.

With the TLS Secret now in place, the Controller instance rewrites the NGINX config file and signals NGINX to reload, securely activating the route(s) to your workload.

## The case for Venafi TLS Protect For Kubernetes

So now you know about cert-manager, what comes next?
Venafi TLS Protect For Kubernetes includes an enterprise-hardened version of cert-manager and the capabilities needed to enable effective machine identity management for OpenShift and Kubernetes clusters in the Enterprise.

So look out for more demos like this, revealing how effective machine identity management can accelerate your cloud native development and prevent application outages or security breaches.

This chapter is complete.

## Rollback
- delete Route53 ALIAS
- `oc project default && oc delete project demos`
- `oc delete clusterissuer letsencrypt`
- OperatorHub
  - Uninstall "cert-manager"
  - Delete "nginxingress-sample" controller instance
  - Uninstall "NGINX Ingress Operator"
- `oc -n nginx-ingress adm policy remove-scc-from-user -z nginx-ingress anyuid`
- `oc -n nginx-ingress adm policy remove-scc-from-user -z nginx-ingress privileged`
- `oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'`

## Appendix
Occasionally, on MacOS, `dig` resolves DNS changes but `curl` does not. If this happens, try this.
```
# https://apple.stackexchange.com/questions/251678/dns-resolution-fails-for-ping-and-curl-but-not-dig
sudo killall -HUP mDNSResponder
```


Next: [Main Menu](/README.md) | [Openshift with ingress-nginx and cert-manager](../02-openshift-ingress-nginx-cert-manager/README.md)
