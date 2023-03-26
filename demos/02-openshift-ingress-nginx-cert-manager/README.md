# Openshift with NGINX Ingress Operator and cert-manager

If you're using Openshift on AWS, what are the minimum steps required to secure a public-facing workload using cert-manager and the NGINX Ingress Operator?
This demo attempts to answer that question.

## Introduction
Your goal here is to enforce secure TLS communication between any browser on the internet and a single containerized workload running in Openshift hosted on AWS.
Much like regular Kubernetes clusters hosted on public cloud providers, Openshift supports safely exposing your workloads to the internet via load balancers.

In this scenario, the browser will expect HTTPS (which implies TLS) but the workload itself only supports HTTP.

We can implement a reverse proxy solution by positioning an nginx instance between an internet-facing load balancer (AWS ELB) and the HTTP workload.
The nginx instance can then be loaded with publicly trusted X.509 certificates making it responsible for TLS termination.
To clarify, this means traffic touching the internet is HTTPS whilst traffic touching the workload is plain old HTTP.

The NGINX Ingress Operator is a packaged version of nginx for deployment inside Openshift clusters via the OperatorHub.
Instead of having to edit nginx configuration files by hand, NGINX Ingress supports declarative configuration via Kubernetes Ingress objects.
Those Ingress objects can reference certificates stored as Kubernetes secrets.
On its own, NGINX Ingress is unable to create certificates or renew them before they expire.
That's where cert-manager and Let's Encrypt come in.

![title](images/nginx-tls-os.png)

## Prerequisites
- The necessary client tools installed
- Access to a running Openshift cluster via `oc` and the console
- Full control of your own domain (or subdomain) surfaced as a **hosted zone** in AWS Route53.

These instructions depend upon content from this directory so `git clone` this repo and `cd` as appropriate.

### Check CLI/console connectivity
Check connectivity via the **CLI**, navigate to the **Console** URL produced and login as `kubeadmin`.
```
oc -n openshift-console get routes console -o=jsonpath="{range}{'https://'}{.spec.host}{'\n'}{end}"
```

Henceforth we will refer to this URL location as https://your-console/.

## The OpenShift OperatorHub
The preferred way to extend OpenShift's capabilities is via the console using OperatorHub.

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

If you wish to watch the nginx-ingress objects as they come online, set up a watch command with the CLI as follows.
```
watch "oc -n openshift-operators get pod,svc"
```

In the case of NGINX Ingress Operator you **do not yet have an Ingress Controller**, just the means to deploy one.
**Before you continue**, you should note that OpenShift has a stricter security posture than vanilla Kubernetes which, by default, would prevent us completing this installation procedure.
The following commands will address this.
```
oc -n nginx-ingress adm policy add-scc-to-user -z nginx-ingress anyuid
oc -n nginx-ingress adm policy add-scc-to-user -z nginx-ingress privileged
```

Only now, can you successfully deploy your NGINX Ingress Controller instance, as follows.
- From the console's navigaton panel, under "Operators", select "Installed Operators".
- Ensure that the "Project" dropdown reads "All Projects"
- Locate the "Nginx Ingress Operator" entry and, under the column named "Provided APIs", click "Nginx Ingress Controller"
- Click "Create NginxIngress"
- Select YAML view
- At about line 31 in the YAML manifest, you should see `secret: nginx-ingress/default-server-secret`.
- You should **remove this line** to ensure a successful installation
- Click "Create"

Your previous `watch` command will reveal further objects as your Ingress Controller comes online.


# TODO this is where I got to, think I did not run the "adm policy add-scc-to-user" lines so controller pod hung, check logs

## Install cert-manager
From the OperatorHub.
- Search for "cert-manager" then click the "cert-manager (Community)" tile
- "Continue" past any warnings, click "Install", accept all default settings and click "Install" once more.

If you wish to watch the cert-manager objects as they come online, set up a watch command with the CLI as follows.
```
watch "oc -n openshift-operators get pod,svc"
```






The following command will install cert-manager via the OperatorHub.



**REDO** just describe this from the UI, THIS must be 100% repeatable 

```
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cert-manager
  namespace: openshift-operators # <-- NOTE non-standard namespace
spec:
  channel: stable
  name: cert-manager
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF
```

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
