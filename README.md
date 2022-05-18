# Overview

This contains a demo for a Consul ECS webinar. It spins up HCP Consul servers with clients in ECS and EKS.

This demo requires a [HashiCorp Cloud Platform (HCP)](https://cloud.hashicorp.com/docs/hcp) account and an AWS Account.

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

* Configure Terraform variables

    Create a `.auto.tfvars` file with the following:

    * `region` - the AWS region where resources will be deployed. Must be one of the [HCP supported regions](https://cloud.hashicorp.com/docs/hcp/supported-env/aws) for the HCP Consul servers.
    * `lb_ingress_ips` - Your IP. This is used in the load balancer security groups to ensure only you can access the demo application.
    * `suffix` - a suffix appended to the name of created resources

    For example,

    ```
    $ cat .auto.tfvars
    region         = "us-east-1"
    lb_ingress_ips = ["<your-ip>/32"]
    suffix         = "demo"
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

* To access the Consul UI in HCP:

    The following will print the URL and bootstrap token to access the Consul UI.
    The bootstrap token can be used to login to Consul.

    ```
    terraform output consul_public_endpoint_url
    terraform output consul_bootstrap_token
    ```

* To access the demo application in ECS:

    The follow prints the URL for the demo application:

    ```
    terraform output ecs_ingress_address
    ```
