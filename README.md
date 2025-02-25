<div align="center">
    <img src="https://github.com/user-attachments/assets/64b338c4-3428-4d67-bb2b-49b7d14422b1" width="30%"/>
</div>  

My collection of notes and configs for my self-hosted, highly-available, lightweight kubernetes cluster. This project was created to study and apply DevOps practices, fully encapsulating concepts such as GitOps, CI/CD, and IaC. 
> **Note**: To host the k3s cluster itself, I have deployed with nearly indentical configurations from https://github.com/techno-tim/k3s-ansible. Please check out his repo to understand why this cluster is highly available and exactly how it was provisioned via Ansible!

***
## DevOps: How It's Applied Here
### GitOps <img src="https://github.com/user-attachments/assets/a8216687-8b82-4e26-8d24-ea3ca3562986" width="3%"/>

I'm pushing the boundaries of  my personal homelab development by embracing a fully Git-driven approach. This empowers me to not only publish my work and experiences but also to create a future-proof, auditable, and easily replicable infrastructure. By syncing my pipeline with my repository, I've automated cluster state management, including rollbacks and updates, with the repo as the source of truth.

###  Infrastructure as Code (IaC) <img src="https://github.com/user-attachments/assets/32cc0c08-f0a3-46a2-9bac-10a4280f8ae1" width="3%"/>

Deploying via IaC allows me to declaratively define infrastructure, leveraging Kubernetes manifests (`.yml`) to specify the desired state of resources like pods, deployments, and services. This inherently facilitates automation for configuring services and applications. To maintain clarity, while all manifests are technically infrastructure, the repository is structured with [/infrastructure](/infrastructure) and [/apps](/apps) directories, distinguishing between internal cluster services (e.g., TLS certificates, reverse proxy) and user-deployed applications. 

[infrastructure](/infrastructure)  
|_ [argocd](/infrastructure/argocd) - State Syncing  
|_ [cert-manager](/infrastructure/cert-manager) - Automated TLS Certificate Management  
|_ [traefik](/infrastructure/traefik) - Reverse Proxy  

### Continuous Integration & Delivery (CI/CD) <img src="https://github.com/user-attachments/assets/28188cfa-3c6f-4a4c-aa6a-2357d719ab18" width="3%"/>

For the purpose of this homelab, I've chosen to decouple the CI piece from the CD piece within the development workflow. CI is handled via Github Actions and its configurtions are detailed within [.github/workflows](.github/workflows). This repo's CI [lints](https://github.com/adrienverge/yamllint) manifests and then performs a security scan on the configurations via [Snyk](https://github.com/snyk/actions).

Once changes are published to the repo, [ArgoCD](https://github.com/argoproj/argo-cd) is able to pull any new or modified changes and apply them directly to my homelab cluster. This tool also allows me to visualize the state and keep track of which versions of my applications that are actively running. More on the CD implementation is detailed [here](/infrastructure/argocd).

## Demo - Simple nginx Deployment

Within my [/apps/nginx-tutorial](/apps/nginx-tutorial) is a kubernetes manifest and accompanying README that has been used for self-teaching on how to utilize this platform. With this deployment, I am able to:
- Utilize GitOps to edit configurations and kick off CI/CD workflows
- Spin up a highly-available replica set of nginx pods
- Create a service to load-balance workloads between the pods
- Create an ingress via traefik to expose the service to my internal network
- Automatically provide the trusted TLS Certificate via cert-manager

