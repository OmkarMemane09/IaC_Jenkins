# Jenkins

<img width="2816" height="1536" alt="IaC" src="https://github.com/user-attachments/assets/10f73dd1-75a6-4814-96c3-38474393c585" />

#  EKS Cluster Infrastructure-as-Code (IaC)

This repository automates the provisioning of a managed **Amazon EKS (Elastic Kubernetes Service)** cluster using **Terraform** and **Jenkins**.

---

##  Architecture Overview

The automation is divided into two logical layers:

### 1. Automation Layer (Jenkins)
* **Pipeline-as-Code:** Uses a declarative Jenkinsfile to manage the infrastructure lifecycle.
* **Safety Gate:** Includes a `terraform plan` review stage with a manual approval step to prevent accidental resource destruction.
* **Security:** Injects AWS credentials securely via Jenkins Credential Manager.

### 2. Infrastructure Layer (AWS EKS)
* **Control Plane:** A fully managed Kubernetes master node (`demo-eks-cluster`).
* **Node Group:** A scalable group of EC2 worker nodes (`c7i-flex.large`) with an auto-scaling configuration (**Min: 1, Desired: 2, Max: 3**).
* **IAM Security:** * `eks-cluster-role`: Grants EKS permission to manage AWS resources.
    * `eks-node-group-role`: Grants worker nodes access to EC2, ECR (for pulling images), and CNI networking.
* **Networking:** Deploys within the Default VPC across all available subnets for high availability.

---

##  Pipeline Stages

| Stage | Purpose |
| :--- | :--- |
| **Checkout** | Clones the Terraform source code from GitHub. |
| **Plan** | Runs `terraform plan` and saves the output to a text file. |
| **Approval** | Pauses execution and displays the plan for human review. |
| **Apply** | Provisions the resources on AWS once approved. |

---

##  Important Configuration Note

The current script uses **ARM64** AMI types with **Intel (c7i)** instances. To ensure compatibility, ensure your `ami_type` matches your `instance_type` architecture:
* For **c7i-flex.large** (Intel): Use `AL2_x86_64`
* For **t4g/c7g** (Graviton/ARM): Use `AL2_ARM_64`
