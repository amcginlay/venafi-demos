# OpenShift with NGINX Ingress Operator and cert-manager

If you're using OpenShift on AWS, what are the minimum steps required to secure a public-facing workload using cert-manager and the NGINX Ingress Operator?
This demo attempts to answer that question.

## Introduction
Your goal here is to enforce secure TLS communication between any browser on the internet and a single containerized workload running in OpenShift hosted on AWS.
Much like regular Kubernetes clusters hosted on public cloud providers, OpenShift supports safely exposing your workloads to the internet via load balancers.

In this scenario, the browser will expect HTTPS (which implies TLS) but the workload itself only supports HTTP.

We can implement a reverse proxy solution by positioning an nginx instance between an internet-facing load balancer (AWS ELB) and the HTTP workload.
The nginx instance can then be loaded with publicly trusted X.509 certificates making it responsible for TLS termination.
To clarify, this means traffic touching the internet is HTTPS whilst traffic touching the workload is plain old HTTP.

The NGINX Ingress Operator is a packaged version of nginx for deployment inside OpenShift clusters via the OperatorHub.
Instead of having to edit nginx configuration files by hand, NGINX Ingress supports declarative configuration via Kubernetes Ingress objects.
Those Ingress objects can reference certificates stored as Kubernetes secrets.
On its own, NGINX Ingress is unable to create certificates or renew them before they expire.
That's where cert-manager and Let's Encrypt come in.

## Your goal
The following diagram illustrates the goal of this exercise.

![title](images/nginx-tls-os.png)

## Prerequisites
- The necessary client tools installed
- Access to a running OpenShift cluster via `oc` and the console
- Full control of your own domain (or subdomain) surfaced as a **hosted zone** in AWS Route53.

These instructions depend upon content from this directory so `git clone` this repo and `cd` as appropriate.

### Check CLI/console connectivity
Check connectivity via the **CLI**, navigate to the **Console** URL produced and login as `kubeadmin`.
```
oc -n openshift-console get routes console -o=jsonpath="{range}{'https://'}{.spec.host}{'\n'}{end}"
```

Henceforth we will refer to this URL location as https://your-console/.

## The OpenShift OperatorHub
The preferred package manager for OpenShift is OperatorHub which is accessible via the console.
When possible, the OperatorHub should be used in preference to traditional Kubernetes tools like Helm.

The OperatorHub is available here https://your-console/operatorhub/all-namespaces

Some of the OperatorHub sources may not be available by default meaning that, for example, the **NGINX Ingress Operator** may appear to be unavailable.
The following patch will ensure Operators from all the default sources are shown.
```
oc patch OperatorHub cluster --type json \
  -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": false}]'
```

## Install NGINX Ingress Operator
From the OperatorHub.
- Search for "nginx ingress" then click the "NGINX Ingress Operator" tile
- Click "Install", accept all default settings and click "Install" once more.

If you wish to watch the nginx-ingress workloads and services as they come online, set up a watch command with the CLI as follows.
```
watch "oc -n openshift-operators get pod,svc"
```

## Deploy NGINX Ingress Controller instance

When installing NGINX Ingress via the OperatorHub **you do not immediately get an Ingress Controller instance**, just the means to deploy one.
OpenShift employs a strict security posture which, by default, would prevent you from completing the deployment.

The following commands will address this restriction.
```
oc -n nginx-ingress adm policy add-scc-to-user -z nginx-ingress anyuid
oc -n nginx-ingress adm policy add-scc-to-user -z nginx-ingress privileged
```

Now you can successfully deploy your NGINX Ingress Controller instance, as follows.
- From the console's navigaton panel, under "Operators", select "Installed Operators"
- Ensure that the "Project" dropdown reads "All Projects"
- Locate the "Nginx Ingress Operator" entry and, under the column named "Provided APIs", click "Nginx Ingress Controller"
- Click "Create NginxIngress"
- Select YAML view
- At about line 31 in the YAML manifest, you should see `secret: nginx-ingress/default-server-secret` (see NOTE below)
- You should **remove this line** to ensure a successful installation
- Click "Create"

NOTE in the interests of simplicity, these instructions omit the pre-provision of the `default-server-secret`, instead choosing to focus on securing specific routes.

Your previous `watch` command will reveal additional workloads and services as your NGINX Ingress Controller instance comes online.
You will observe your new service object is of type LoadBalancer, with the EXTERNAL-IP column identifying the associated AWS Load Balancer.

After 2-3 mins the load balancer will begin returning "404 Not Found" responses.
This is the expected response since no Ingress rules have been applied to NGINX yet.
```
elb_dnsname=$(oc -n nginx-ingress get service nginxingress-sample-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -L http://${elb_dnsname}
```

## Configure Route53

NOTE if you wish to complete this section using the AWS CLI, check out the necessary steps detailed in the [addendum](./addendum/README.md).

To pair your own web domain with an AWS load balancer you will need full control of the appropriate **hosted zone** in a public DNS service.
These instructions assume that service is AWS Route53.

The following section details the assignment of a new Route53 ALIAS record to your domain (or subdomain) which can route traffic to the ELB you created previously.

NOTE using day of the month in the DNS record (below) is a simplistic way to test out your solution using **production-strength** certificates whilst navigating the CA's [Duplicate Certificate Limit](https://letsencrypt.org/docs/duplicate-certificate-limit/).

Start by setting variables to represent the DNS record name you wish to target.
```bash
hosted_zone=venafi.mcginlay.net   # IMPORTANT - adjust as appropriate
record_subdomain_name=www$(date +"%d") # e.g. www01 - where the digits indicate the day of the month (for testing)
export DNS_RECORD_NAME=${record_subdomain_name}.${hosted_zone}
echo
echo "TODO: Route53 ALIAS required between DNS record ${DNS_RECORD_NAME}" and ${elb_dnsname}
```

Head over to https://console.aws.amazon.com/route53/v2/hostedzones and create your new DNS record in your hosted zone as shown below.

![title](images/route53.png)

Once the DNS record has propagated, the new endpoint will also respond with the familiar "404" status page from `nginx`.
Wait for this to happen before continuing.
```bash
curl -L http://${DNS_RECORD_NAME}
```

## Your goal (checkpoint 1)
The following diagram illustrates your progress towards the goal of this exercise.

![title](images/nginx-tls-os-partial-1.png)

## Install cert-manager
From the OperatorHub.
- Search for "cert-manager" then click the "cert-manager (Community)" tile
- "Continue" past any warnings, click "Install", accept all default settings and click "Install" once more.

If you wish to watch the cert-manager workloads and services as they come online, set up a watch command with the CLI as follows.
```
watch "oc -n openshift-operators get pod,svc"
```

The OperatorHub install of cert-manager does not require any patching and automatically deploys the required workloads.

## Create Let's Encrypt (ACME) issuer
cert-manager is unable to oversee the creation of any certificates until you have at least one Issuer in place.
The simplest way to create the publicly trusted certificates you require is via [Let's Encrypt](https://letsencrypt.org/), so go ahead and set up a cluster-wide issuer for that.
```
export EMAIL=jbloggs@gmail.com # <-- change this to suit

envsubst <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt
    solvers:
      - http01:
          ingress:
            class:  nginx
EOF
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

Note: `oc new-app` automatically creates a ClusterIP service for your workload.
`oc expose` can create a publicly accessible route via Openshift's default ingress controller but you want your NGINX Ingress Controller to take on this responsibility via an Ingress rule.

## Your goal (checkpoint 2)
The following diagram illustrates your progress towards the goal of this exercise.

![title](images/nginx-tls-os-partial-2.png)

## Creating an Ingress rule

As mentioned, your NGINX Ingress Controller instance is not currently loaded with any routing rules, hence the "404" responses we currently see via the load balancer.
Outside the world of OpenShift and Kubernetes, "vanilla" NGINX would source its rules from a config file (`nginx.conf`).
NGINX Ingress Controller instances works the same, except the controller component ingests Ingress objects and codifies them into config file modifications on your behalf.

As you create your first Ingress object, observe the use of the `ingressClassName` attribute which associates your Ingress rule with a specific variant of Ingress controller (`nginx`), and the `cert-manager.io/issuer` annotation which associates your rule with your Issuer object (`letsencrypt`).
```bash
export CERTIFICATE=$(tr \. - <<< ${DNS_RECORD_NAME})-tls

envsubst <<EOF | oc -n demos apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress
  annotations:
    cert-manager.io/issuer: "letsencrypt" # TLS requirement - enables cert-manager
spec:
  ingressClassName: nginx                 # instruct NGINX Ingress controller to ingest this Ingress object
  tls:                                    # TLS requirement
  - hosts:                                # TLS requirement
    - ${DNS_RECORD_NAME}                  # TLS requirement - domain name(s) to secure
    secretName: ${CERTIFICATE}            # TLS requirement - certificate stored here
  rules:
  - host: ${DNS_RECORD_NAME}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-app
            port:
              number: 8080
EOF
```

You can observe your ingress object as follows.
Note that this supports traffic on port 443 (HTTPS).
```bash
kubectl -n demos get ingress openshift-test
```

Your ELB will now **securely** route all traffic via HTTPS to your demo workload.
```bash
curl -Ls https://${DNS_RECORD_NAME}
```

At this point you can navigate to the `${DNS_RECORD_NAME}` URL in any browser and you will see padlock icons without warnings meaning HTTPS is enforced and working.
By observing the output in a browser you can also determine that the request your workload received was plain old HTTP.
This means nginx done its job - it has routed traffic from the ELB to your workload, meanwhile providing a transparent termination point for the TLS encryption.

## So, what just happened?

cert-manager is aware of Ingress objects.

It deduced from your Ingress object that traffic to `openshift-test` is intended to be secured by Let's Encrypt and silently built a cert-manager Certificate object to represent that requirement.
The presence of that Certificate object triggers a sequence of events in cert-manager which ultimately causes a new [TLS secret](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets) to be deposited in the demos namespace.
This, in turn, causes the NGINX Ingress controller to update the NGINX config file and perform a soft-reset of NGINX workload.

# TODO from here ^^^^

causes a CertificateRequest (CR) object to be issued by cert-manager.
Each CR that is successfully fulfilled causes the associated certificate to become paired with a secret object containing the key material returned from the CA.

You can view the paired objects as follows.
```bash
kubectl -n demos get certificate ${certificate}
kubectl -n demos describe secret ${certificate} | tail -4
```

The data items in the secrets are base64 encoded.
If you wish, you can use `openssl` to see the certificate material in its more natural form.
```bash
kubectl -n demos get secret ${certificate} -o 'go-template={{index .data "tls.crt"}}' | base64 --decode | openssl x509 -noout -text | head -11
```

As expected for an ingress controller, ingress-nginx is also aware of ingress objects.

With the secret containing a certificate now in place, ingress-nginx rewrites the nginx config file and signals nginx to reload, securely activating the route(s) to your workload.

## The case for Venafi TLS Protect For Kubernetes

So now you know about `cert-manager`, what next?
Venafi TLS Protect For Kubernetes includes an enterprise-hardened version of `cert-manager` along with a number of machine identity management capabilities needed to support Kubernetes machine identities on an enterprise-basis.

So look out for more demos in the future, revealing what else is possible.

This chapter is complete.






<!--
cert-manager is unable to oversee the creation of any certificates until you have at least one Issuer in place.
The simplest way to create the publicly trusted certificates you require is via Let's Encrypt, so go ahead and set up a cluster-wide issuer for that now.
```
export EMAIL=jbloggs@gmail.com # <-- change this to suit
envsubst <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt
    solvers:
      - http01:
          ingress:
            class:  nginx
EOF
```

## Install and configure NGINX Ingress
The following command will install NGINX Ingress Opertaor via the OperatorHub.

**REDO** just describe this from the UI, THIS must be 100% repeatable 

```
oc new-project nginx-ingress # <-- TEST ON NEW CLUSTER, SEE IF NECESSARY!
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nginx-ingress-operator
  namespace: nginx-ingress
spec:
  channel: alpha
  name: nginx-ingress-operator
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF
```

TODO continue from here ...
-->

Next: [Main Menu](/README.md) | [Openshift with ingress-nginx and cert-manager](../02-openshift-ingress-nginx-cert-manager/README.md)
