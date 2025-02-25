# Demo - Simple nginx Deployment

In this demo I will go over exactly how I deploy new applications to my homelab as well as how everything works together within the cluster.

I will be highlighting:
- GitOps Practices
- CI/CD Pipeline
  - CI Github Actions Workflow
  - CD ArgoCD Deployment Workflow
- Kubernetes Objects Created
- IaC Services
  - cert-manager
  - traefik

## GitOps

Since git is essentially now the control plane in which we can deploy and manage our applictions, it's useful to follow a basic branching strategy. This tends to vary based on project requirements, but my personal workflow is as follows:

`development` -> `Index` -> `test` -> `production`

By organizing the flow of merges, `development` contains the most conceptual/ likely to break state of the environment. However, after propogating through the CI checks, merging `development` into `Index` will allow this branch to hold the most current state of the environment that is *to-be* deployed to the cluster. 

Finally, merging `Index` into `test` allows for test to run through its CI checks, while also syncing with `Index`. At this point, `development` and `test` are synced with `Index`.

Once the `test` CI checks clear, I am able to create a pull request that merges `test` into `production`. The only commits to production are via pull requests. The state of production then becomes the state of the cluster as it enters the CD workflow.

By having my repo modifications jump through so many hoops, it allows for extensive CI and testing, and explicit approval for the pull request into `production` before my CD workflow kicks off and makes actual changes to my homelab cluster.

## CI/CD Pipeline
### CI Workflow
The CI workflow is configured to kick off whenever there is a push to the development and test branches as well as the final pull request to production, ensuring that every change at every stage goes through the pipeline. 

[CI Triggers](/.github/workflows/ci.yml#L4-L11)
```yaml
on:
  push:
    branches:
      - development
      - test
  pull_request:
    branches:
      - production
```

As of writing this demo guide, my CI implementation first lints the kubernetes manifests (`.yml`) for proper formatting, then it kicks off a security scan provided by a Github Action called `snyk`. This scan catches things such as misconfigurations and vulnerable image tags. 

Example Snyk CI Output:
```
Snyk Infrastructure as Code

- Snyk testing Infrastructure as Code configuration issues.
✔ Test completed.

Issues

Medium Severity Issues: 3

  [Medium] Container or Pod is running without root user control
  Info:    Container or Pod is running without root user control. Container or
           Pod could be running with full administrative privileges
  Rule:    https://security.snyk.io/rules/cloud/SNYK-CC-K8S-10
  Path:    [DocId: 1] > input > spec > template > spec > containers[nginx] >
           securityContext > runAsNonRoot
  File:    apps/nginx-tutorial/nginx.yml
  Resolve: Set `securityContext.runAsNonRoot` to `true`
.
.
.
```

Once my changes are ready to propogate past the `test` stage, the pull request to merge from `test` to `production` kicks off a final CI workflow to ensure that we don't commit anything that we don't mean to.

### CD Workflow
The CD workflow is where the deployment to the cluster finally takes place. This is self-hosted within the cluster itself and syncs to this repo's `production` branch.

By continuously scanning the repo's prodution branch for any changes, `ArgoCD` parses the application's manifest and creates the specified Kubernetes objects within the cluster. Argo specifically also provides a very insightful UI that can help us vizualize the deployment more easily.

Kubernetes Objects via ArgoCD:

![image](https://github.com/user-attachments/assets/46f2e23f-5eb2-4a8f-80f5-2953024b74b3)

## Kubernetes Objects Created

In reference to [nginx.yml](/apps/nginx-tutorial/nginx.yml) there are 3 essential `kind`'s of objects created, namely the namespace, deployment, and service. The `nginx` namespace helps us compartmentalize our application and define objects within it to reference. The deployment contains the configurations for the pods/containers themselves, including the image and port to expose. The service is what creates a ClusterIP. This object essentially acts as an internal load balancer that will route workloads through each pod as needed. To clarify, let's take a look at these objects.

Container/Pod Info:
```
$ kubectl get pods -n nginx -o wide
NAME                     READY   STATUS    RESTARTS   AGE    IP            NODE            NOMINATED NODE   READINESS GATES
nginx-7bdc5b79d4-8fk7f   1/1     Running   0          162m   10.42.3.61    wnk3s-app-001   <none>           <none>
nginx-7bdc5b79d4-hzqc8   1/1     Running   0          162m   10.42.4.131   wnk3s-app-002   <none>           <none>
nginx-7bdc5b79d4-qfq4s   1/1     Running   0          162m   10.42.4.132   wnk3s-app-002   <none>           <none>
```
Service Object:
```
$ kubectl get service -n nginx
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
nginx   ClusterIP   10.43.107.182   <none>        80/TCP    162m
```
Internally to the cluster, ClusterIP `10.43.107.182` will loadbalance workloads headed for our deployment between `10.42.3.61`, `10.42.4.131`, and `10.42.4.132`. 

Now, this nginx service is technically up and running with just these objects; however, this is only *internal to the cluster*, so we have to leverage some of our infrastructure services to expose the service via a reverse proxy.

## IaC Services
### cert-manager
`cert-manager` is a very powerful tool for automating certificate provisioning and lifecycles. With my homelab configuration, it essentially acts as a Cert Authority as well as an issuer, allowing the creation of kubernetes secrets that may be used by the nginx application.
> *note*: As this is a homelab where I don't expose services to the internet, I created my own CA to issue self-signed certs that my clients are configured to trust. 

The following snippet from [nginx.yml](/apps/nginx-tutorial/nginx.yml#L41-L53):
```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx-certificate
  namespace: nginx
spec:
  secretName: nginx-certificate-secret
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
    - nginx.home.lab
```
leverages the cert-manager api in order to issue a new tls certificate to my internal domain `nginx.home.lab`. This secret becomes available to the `nginx` namespace for our ingress controller to use.
> *note*: This internal domain must be setup with whatever DNS provider your clients will be using (router, dns server, os, etc.)

Kubernetes Secret Object/ Certificate:
```
$ kubectl describe secret nginx-certificate-secret -n nginx
Name:         nginx-certificate-secret
Namespace:    nginx
Labels:       controller.cert-manager.io/fao=true
Annotations:  cert-manager.io/alt-names: nginx.home.lab
              cert-manager.io/certificate-name: nginx-certificate
              cert-manager.io/common-name: 
              cert-manager.io/ip-sans: 
              cert-manager.io/issuer-group: 
              cert-manager.io/issuer-kind: ClusterIssuer
              cert-manager.io/issuer-name: selfsigned-cluster-issuer
              cert-manager.io/uri-sans: 

Type:  kubernetes.io/tls

Data
====
ca.crt:   2017 bytes
tls.crt:  1545 bytes
tls.key:  1679 bytes
```

### traefik
`traefik` runs as a pod that can act as a reverse proxy to expose an ingress to my home network LAN. As a reverse proxy it also redirects to https and manages the tls cert that was generated using `cert-manager`.
> **note**: more details on the architecture of the network can be found at [/infrastructure/traefik](/infrastructure/traefik)

The following snippet defines the ingress object created for our nginx service:
```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: nginx
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  rules:
    - host: nginx.home.lab
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  number: 80
  tls:
    - hosts:
        - nginx.home.lab
      secretName: nginx-certificate-secret
```

nginx-ingress via traefik:
```
Name:             nginx-ingress
Labels:           app.kubernetes.io/instance=nginx-demo
Namespace:        nginx
Address:          10.0.0.81
Ingress Class:    traefik
Default backend:  <default>
TLS:
  nginx-certificate-secret terminates nginx.home.lab
Rules:
  Host            Path  Backends
  ----            ----  --------
  nginx.home.lab  
                  /   nginx:80 (10.42.3.61:80,10.42.4.132:80,10.42.4.131:80)
Annotations:      traefik.ingress.kubernetes.io/router.entrypoints: websecure
Events:           <none>
```

Now that the ingress is setup, I can access it from my private LAN on address `10.0.0.81`. Therefore any requests made to `https://nginx.home.lab` will go through traefik at `10.0.0.81` and be forwarded through to our nginx pods. So, from the browser, we can finally see our exposed application over the LAN.

![image](https://github.com/user-attachments/assets/c06383c5-df76-4bf3-8484-a3ddc67ba4d0)





