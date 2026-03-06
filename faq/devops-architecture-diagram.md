# DevOps Architecture Diagram

This document contains a single high-level architecture diagram for the
project.

## Full CI/CD + GitOps Architecture

``` mermaid
flowchart LR

  subgraph DEV["Developer Workflow"]
    A[Developer]
    B[Feature Branch]
    C[Pull Request to kubernetes-test-helm]
    A --> B --> C
  end

  subgraph GH["GitHub Repository"]
    D[kubernetes-test-helm branch]
    E[".github/workflows/ci-pr.yml"]
    F[".github/workflows/gitops-ci.yml"]
    G["Bot PR: update Helm image tags"]
    H["Helm charts: helm/selmag"]
    I["ArgoCD apps: argocd/apps"]
  end

  subgraph ACTIONS["GitHub Actions"]
    J[CI PR verify]
    K[mvn verify]
    L[GitOps CI]
    M[mvn package]
    N[Build Docker images]
    O[Push images]
    P[Create PR with new sha tags]
  end

  subgraph GHCR["GitHub Container Registry"]
    Q["ghcr.io/gitueser/selmag/admin-server:sha-xxxxxxx"]
    R["ghcr.io/gitueser/selmag/api-gateway:sha-xxxxxxx"]
    S["ghcr.io/gitueser/selmag/catalogue-service:sha-xxxxxxx"]
    T["ghcr.io/gitueser/selmag/config-server:sha-xxxxxxx"]
    U["ghcr.io/gitueser/selmag/customer-app:sha-xxxxxxx"]
    V["ghcr.io/gitueser/selmag/eureka-server:sha-xxxxxxx"]
    W["ghcr.io/gitueser/selmag/feedback-service:sha-xxxxxxx"]
    X["ghcr.io/gitueser/selmag/manager-app:sha-xxxxxxx"]
  end

  subgraph ARGO["ArgoCD"]
    Y["root.yaml"]
    Z["selmag.yaml"]
    AA["Auto-Sync / Sync"]
  end

  subgraph K8S["Kubernetes Cluster (minikube)"]
    AB["Namespace: selmag-helm"]
    AC["Deployments"]
    AD["Pods with images sha-xxxxxxx"]
    AE["Services / Ingress"]
  end

  subgraph INFRA["Infra components in cluster (dev setup)"]
    AF["PostgreSQL"]
    AG["MongoDB"]
    AH["Keycloak"]
    AI["Observability stack"]
  end

  C --> J
  E --> J
  J --> K
  K -->|PR checks pass| D

  D --> L
  F --> L
  L --> M --> N --> O
  O --> Q
  O --> R
  O --> S
  O --> T
  O --> U
  O --> V
  O --> W
  O --> X
  O --> P
  P --> G
  G --> D

  H --> Z
  I --> Y
  Y --> Z
  D --> H
  D --> I

  Z --> AA
  AA --> AB
  AB --> AC --> AD
  AC --> AE

  AB --> AF
  AB --> AG
  AB --> AH
  AB --> AI
```

## Short explanation

1.  Developer creates a feature branch and opens a PR into
    `kubernetes-test-helm`.
2.  `ci-pr.yml` runs validation (`mvn verify`).
3.  After merge, `gitops-ci.yml` builds JARs, Docker images, and pushes
    them to GHCR.
4.  The pipeline creates a bot PR that updates Helm image tags to the
    new `sha-<shortsha>`.
5.  After merging that PR, ArgoCD detects the Helm change and deploys
    the new images into the cluster.
6.  PostgreSQL, MongoDB, Keycloak, and observability are infrastructure
    components and are not built by the CI pipeline.

## Notes

-   Application images are stored in **GHCR**.
-   Deployment source of truth is the **`kubernetes-test-helm` branch**.
-   ArgoCD reads manifests from Git and applies them to Kubernetes.
-   Running image versions are verified through `kubectl` and image
    digests.
