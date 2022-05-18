# Overview

This contains a demo for a Consul ECS webinar. It spins up HCP Consul servers with clients in ECS and EKS.

# Quickstart

* Set HCP credentials

    ```
    export HCP_CLIENT_ID=...
    export HCP_CLIENT_SECREt=...
    ```

* Set AWS credentials

    ```
    AWS_ACCESS_KEY_ID=...
    AWS_SECRET_ACCESS_KEY=...
    AWS_SESSION_TOKEN=...
    ```

* Run terraform

    ```
    terraform init
    terraform apply
    ```

* (optional) Configure kubectl

    ```
    aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw local.eks_cluster_name)
    kubectl get pods -A
    ```
