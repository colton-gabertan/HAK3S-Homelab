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

### GitOps

Since git is essentially now the control plane in which we can deploy and manage our applictions, it's useful to follow a basic branching strategy. This tends to vary based on project requirements, but my personal workflow is as follows:

`development` -> `Index` -> `test` -> `production`

By organizing the flow of merges, `development` contains the most conceptual/ likely to break state of the environment. However, after propogating through the CI checks, merging `development` into `Index` will allow this branch to hold the most current state of the environment that is *to-be* deployed to the cluster. 

Finally, merging `Index` into `test` allows for test to run through its CI checks, while also syncing with `Index`. At this point, `development` and `test` are synced with `Index`.

Once the `test` CI checks clear, I am able to create a pull request that merges `test` into `production`. The only commits to production are via pull requests. The state of production then becomes the state of the cluster as it enters the CD workflow.

By having my repo modifications jump through so many hoops, it allows for extensive CI and testing, and explicit approval for the pull request into `production` before my CD workflow kicks off and makes actual changes to my homelab cluster.

### CI/CD Pipeline
#### CI Workflow
The CI workflow is configured to kick off whenever there is a push to the development and test branches as well as the final pull request to production, ensuring that every change at every stage goes through the pipeline. 

As of writing this demo guide, my CI implementation first lints the kubernetes manifests (`.yml`) for proper formatting, then it kicks off a security scan provided by a Github Action called `snyk`. This scan catches things such as misconfigurations and vulnerable image tags. 

Once my changes are ready to propogate past the `test` stage, the pull request to merge from `test` to `production` kicks off a final CI workflow to ensure that we don't commit anything that we don't mean to.

#### CD Workflow
The CD workflow is where the deployment to the cluster finally takes place. This is self-hosted within the cluster itself and syncs to this repo's `production` branch.

By continuously scanning the repo's prodution branch for any changes, `ArgoCD` parses the application's manifest and creates the specified Kubernetes objects within the cluster. Argo specifically also provides a very insightful UI that can help us vizualize the deployment more easily. 


