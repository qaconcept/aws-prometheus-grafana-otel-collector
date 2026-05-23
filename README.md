# AWS HA Observability Stack (AWS Prometheus + Grafana + OpenTelemetry Collector)

> **A production-grade, highly available, open-source observability pipeline engineered on AWS using a strictly isolated, layered Terraform design pattern.**

---

## Table of Contents

- [About / Overview](#about--overview)
- [Goals of the Repository](#goals-of-the-repository)
- [AWS Well-Architected Framework Alignment](#aws-well-architected-framework-alignment)
- [Site Reliability Engineering (SRE) Maturity](#site-reliability-engineering-sre-maturity)
- [Architecture \& Structural Layers](#architecture--structural-layers)
- [Prerequisites](#prerequisites)
- [Local Setup \& Forking Instructions](#local-setup--forking-instructions)
- [Deployment \& Execution Steps](#deployment--execution-steps)
- [Usage \& Telemetry Verification](#usage--telemetry-verification)
- [Monitoring \& Maintenance](#monitoring--maintenance)
- [Cleanup / Teardown](#cleanup--teardown)
- [Contributing](#contributing)
- [License](#license)
- [References / Further Reading](#references--further-reading)

---

## About / Overview

Modern microservice architectures generate massive volumes of distributed telemetry points that are difficult to centralize without running into high SaaS costs or complex vendor lock-ins. This repository provides a scalable alternative: a fully customizable, open-source telemetry engine built inside your own AWS perimeter.

By orchestrating the cloud infrastructure through modular, independent deployment phases, this project provisions an **OpenTelemetry-native** ingest network alongside dedicated Prometheus, Jaeger, and Grafana clusters. This ensures your engineering teams have uncompromised, zero-egress data visibility over internal compute environments.

---

## Goals of the Repository

* **Modular Isolation:** Break down large cloud structures into independent infrastructure layers to prevent widespread blast radiuses during updates.
* **Open Standardization:** Avoid proprietary tracking tools by using OpenTelemetry components for handling logs, metrics, and traces.
* **Enterprise Security Standards:** Enforce explicit security boundaries around your metrics by keeping telemetry ingest traffic strictly within private network paths.
* **Persistent Operations:** Ensure long-term system durability by running stateful storage instances over AWS managed storage layers.

---

## AWS Well-Architected Framework Alignment

### 1. Security (Least Privilege & Explicit Boundaries)

* **Private Network Isolations:** Every single compute engine (Prometheus, Jaeger, Grafana, and the Collector) runs inside isolated, private subnets. They cannot be reached directly from the internet.
* **Strict Security Group Matrices:** Security groups are mapped to follow the principle of least privilege. Ingress rules are strictly bounded to exact service requirements (e.g., port `4317`/`4318` for incoming OTLP streams, `9090` for Prometheus scraping).
* **Encryption Everywhere:** Data is encrypted both in transit using TLS certificates managed by AWS Certificate Manager (ACM) and at rest using Amazon EFS with native AWS KMS encryption keys.

### 2. Reliability (High Availability Design)

* **Multi-AZ Availability:** Services are automatically distributed across multiple AWS Availability Zones (`us-east-1a` and `us-east-1b`) to handle potential localized data center outages.
* **Self-Healing Infrastructure:** All core platforms run as Amazon ECS Fargate tasks. If a container crashes, locks up, or fails an internal health probe, the ECS scheduler automatically flags it, drops it from the application load balancer, and deploys a fresh instance.

### 3. Cost Optimization (Pragmatic In-VPC Engineering)

* **Single Managed NAT Topology:** To balance costs with system availability, internal systems funnel outbound public requests (such as public container registry pulls or security patches) through a single AWS NAT Gateway instances. Because 99% of internal metric ingestion stays entirely within private IP blocks, this design cuts out redundant multi-AZ NAT idle service fees while keeping the platform operational.

### 4. Operational Excellence (Observability as Code)

* **Idempotent Infrastructure Pipelines:** The entire platform infrastructure is structured through declarative Terraform code blocks, ensuring identical deployments across multiple sandbox, staging, and production AWS accounts.

### 5. Performance Efficiency & Sustainability

* **Serverless Elastic Compute:** Running workloads over AWS Fargate eliminates the overhead of managing underlying EC2 host instances. Compute and memory scaling maps cleanly to container resource usage, reducing excess power footprints and idle hardware consumption.

---

## Site Reliability Engineering (SRE) Maturity

This repository is built around key SRE operational standards:

* **Native SLI/SLO Readiness:** The OpenTelemetry collector establishes clear data ingestion baselines, allowing teams to easily calculate Service Level Indicators (SLIs) like request rates, error ratios, and system latency.
* **Toil Minimization:** Routine deployment setups, data variables synchronization, and infrastructure adjustments are entirely automated via a unified management wrapper script (`sync-vars.sh`), removing manual configuration errors.
* **Continuous Active Health Checking:** Rather than checking if a container's basic Linux process is alive, every app infrastructure file is built with precise internal application-level checks.

| Service Component | Internal Test Method | Targeted Endpoint Port |
| --- | --- | --- |
| **OpenTelemetry Collector** | OTLP Status Monitoring Extension | Extension Port `:13133` / HTTP `:4318` |
| **Jaeger Ingest Backend** | Native Admin Portal Ingress API | Internal Ingress Port `:14269/` |
| **Prometheus Core Engine** | Inherent Platform Health Hook | Native Target Port `:9090/-/healthy` |
| **Grafana Visual Layer** | Sub-system Component Readiness Endpoint | Container Target Port `:3000/api/health` |

---

## Architecture & Structural Layers

The codebase is organized into isolated structural modules. This layout ensures you can apply modifications to high-level frontend interfaces (like Grafana) without risking updates to foundational core network resources (like the VPC layout).

![AWS HA Observability Stack Architecture Diagram](images/AWS-HA-Observability-Stack_AWS-Prometheus-Jaeger-OpenTelemetry-Collector-Grafana.png)

```
 ┌────────────────────────────────────────────────────────┐
 │           08-grafana-dashboards (HTTPS GUI)           │
 └───────────────────────────┬────────────────────────────┘
                             ▼
 ┌────────────────────────────────────────────────────────┐
 │            07-prometheus-ecs (TSDB Storage)            │
 └───────────────────────────┬────────────────────────────┘
                             ▼
 ┌────────────────────────────────────────────────────────┐
 │         06-jaeger-tracing / 05-otel-collector          │
 └───────────────────────────┬────────────────────────────┘
                             ▼
 ┌────────────────────────────────────────────────────────┐
 │    04-ecs-fargate-cluster / 03-ecr-repositories        │
 └───────────────────────────┬────────────────────────────┘
                             ▼
 ┌────────────────────────────────────────────────────────┐
 │        02-security-groups / 01-vpc-network             │
 └────────────────────────────────────────────────────────┘

```

### Layer Manifest Details

* **`01-vpc: Base networking.
* **`02-ingress-egress: Security group boundaries.
* **`03-storage: EFS persistent storage configuration.
* **`04-iam: IAM roles and policies.
* **`05-obs-backend-jaeger: Tracing backend.
* **`06-obs-backend-prometheus: Metrics TSDB.
* **`07-obs-frontend-grafana: Visualization layer.
* **`08-obs-collector: OTEL collection pipeline.
---

## Prerequisites

Before starting, make sure your local machine and cloud environments have the following tools and configurations ready:

* **AWS Account Access:** An active AWS account with administrative permissions covering VPC, ECS, Route 53, ACM, and EFS resource controls.
* **Dedicated Route 53 Hosted Zone:** A public domain zone registered inside Route 53.
> ⚠️ **CRITICAL REQUIREMENT:** The hosted zone must contain *only* its initial, default SOA (Start of Authority) and NS (Name Server) records. Clean out any pre-existing routing entries before deployment to avoid certificate verification locks during the setup of the shared Application Load Balancer.


* **AWS CLI Tooling:** Installed and configured locally via `aws configure` with standard administrative secret access keys.
* **Terraform Binary:** Recommendation: `v1.5.0` or newer.
* **Git Engine:** For cloning and tracking updates.

---

## Local Setup & Forking Instructions

### 1. Fork the Workspace Repository

Navigate to [https://github.com/qaconcept/aws-prometheus-grafana-otel-collector](https://github.com/qaconcept/aws-prometheus-grafana-otel-collector) and click **Fork** in the upper right corner to clone a copy into your personal GitHub account namespace.

### 2. Clone Your Fork Locally

Open your terminal and run:

```bash
git clone https://github.com/<YOUR-GITHUB-USERNAME>/aws-prometheus-grafana-otel-collector.git
cd aws-prometheus-grafana-otel-collector

```

### 3. Configure Local Environmental Security

To safeguard your cloud environments, never hardcode access keys into your project configuration files. Instead, load them into your active terminal sessions via standard environmental exports:

```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUptFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_DEFAULT_REGION="us-east-1"

```

---

## Deployment & Execution Steps

### Step 1: Customize Variables Space

In the root directory of the repository, copy or edit the existing `central.tfvars` template file to fit your specific cloud variables:

```hcl
# Example values inside your central.tfvars
project_name        = "sre-concepts"
region              = "us-east-1"
aws_region          = "us-east-1"
environment         = "dev"
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
domain_name         = "sreconcepts.com"
# Set to true to create a new ACM cert, false to use the existing one
create_ssl_cert     = false

* **'If create_ssl_cert = false: Terraform uses a data source to fetch the existing certificate for *.yourdomain.com and yourdomain.com.
* **'If create_ssl_cert = true: Terraform creates a new *.yourdomain.com certificate and performs DNS validation via Route 53.
```

### Step 2: Sequential Phased Layer Deployment

Because subsequent modules rely on inputs from earlier layers, you must deploy the layers sequentially from the root directory (aws-prometheus-grafana-otel-collector/terraform).

Run the following commands:

```bash
# Initialize and Apply Phase 1: Base networking.
cd layers/01-vpc
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 01
cd layers/01-vpc 
chmod +x validate.sh
./validate.sh  

# Initialize and Apply Phase 2: Security group boundaries.
cd layers/02-ingress-egress
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 02
cd layers/02-ingress-egress
chmod +x validate.sh
./validate.sh  

# Initialize and Apply Phase 3: EFS persistent storage configuration.
cd layers/03-storage
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 03
cd layers/03-storage
chmod +x validate.sh
./validate.sh  

# Initialize and Apply Phase 4: IAM roles and policies.
cd layers/04-iam
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 04
cd layers/04-iam
chmod +x validate.sh
./validate.sh  

# Initialize and Apply Phase 5: Tracing backend. Also ACM Certificate if needed
cd layers/05-obs-backend-jaeger
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 05
cd layers/05-obs-backend-jaeger
chmod +x validate.sh
# Note: Ensure ECS Task is running and healthy prior to running ./validate.sh  
./validate.sh  

# Initialize and Apply Phase 6: Metrics TSDB.
cd layers/06-obs-backend-prometheus
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 06
cd layers/06-obs-backend-prometheus
chmod +x validate.sh
# Note: Ensure ECS Task is running and healthy prior to running ./validate.sh  
./validate.sh  

# Initialize and Apply Phase 7: Visualization layer.
cd layers/07-obs-frontend-grafana
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 07
cd layers/07-obs-frontend-grafana
chmod +x validate.sh
# Note: Ensure ECS Task is running and healthy prior to running ./validate.sh  
./validate.sh  

# Initialize and Apply Phase 8: OTEL collection pipeline.
cd layers/08-obs-collector
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 08
cd layers/08-obs-collector
chmod +x validate.sh
# Note: Ensure ECS Task is running and healthy prior to running ./validate.sh  
./validate.sh

```

> **Note:** The `sync-vars.sh` helper utility runs after each deployment step. It extracts newly generated IDs (like Subnet IDs, Security Group IDs, or Target Group ARNs) and injects them into downstream variables files so subsequent modules can ingest them dynamically.

---

## Usage & Telemetry Verification

Once Layer 08 is fully deployed, all endpoints are verified and secured via HTTPS through Route 53 routing tables.

### 1. Accessing Your Core Portals

Open your web browser and navigate to your configured domain paths:

* **Grafana Visual UI:** `https://grafana.yourdomain.com` (Default login user: `admin` / Password: 'admin123 ).
* **Prometheus Dashboard:** `https://prometheus.yourdomain.com`
* **Jaeger Ingest UI:** `https://jaeger.yourdomain.com`


```

---

## Monitoring & Maintenance

### EFS Storage Backup Operations

Your active tracking data is saved to AWS Elastic File System (EFS) volumes to protect your metrics and dashboards against container changes. System snapshots are managed through AWS Backup schedules.

### Inspecting Infrastructure Logs

If an application container fails to start, check its log messages inside the AWS CloudWatch Log Groups console under these paths:

* `/ecs/sre-concepts/otel-collector`
* `/ecs/sre-concepts/prometheus`
* `/ecs/sre-concepts/grafana`

---

## Cleanup / Teardown

To avoid incurring unexpected charges on your cloud statement, clean up all provisioned resources when you're done testing. Because your layers have interconnected dependencies, you must destroy them in the **exact reverse order** they were deployed.

Run this command sequence:

```bash
# Execute from root terraform folder
terraform -chdir=layers/08-obs-collector destroy -var-file="../../central.tfvars" -auto-approve
terraform -chdir=layers/07-obs-frontend-grafana destroy -var-file="../../central.tfvars" -auto-approve
terraform -chdir=layers/06-obs-backend-prometheus destroy -var-file="../../central.tfvars" -auto-approve
terraform -chdir=layers/05-obs-backend-jaeger destroy -var-file="../../central.tfvars" -auto-approve
terraform -chdir=layers/04-iam destroy -var-file="../../central.tfvars" -auto-approve
terraform -chdir=layers/03-storage destroy -var-file="../../central.tfvars" -auto-approve 
terraform -chdir=layers/02-ingress-egress destroy -var-file="../../central.tfvars" -auto-approve
terraform -chdir=layers/01-vpc destroy -var-file="../../central.tfvars" -auto-approve

```

---

## Contributing

We welcome community feedback, issue reports, and pull requests! To suggest changes:

1. Open a tracking issue describing your proposal.
2. Implement your adjustments inside a dedicated local topic branch.
3. Submit a pull request against our `main` target development branch for code review.

---

## License

This project is open-source software licensed under the terms of the [MIT License](https://www.google.com/search?q=LICENSE).

---

## References / Further Reading

* [Official OpenTelemetry Collector Custom Configurations Core Docs](https://www.google.com/search?q=https://opentelemetry.io/docs/collector/)
* [AWS Well-Architected Framework Pillars Guide Overview](https://www.google.com/search?q=https://aws.amazon.com/architecture/well-architected/)
* [Managing Persistent File Volumes with Amazon ECS Fargate on EFS Drives](https://www.google.com/search?q=https://docs.aws.amazon.com/AmazonECS/latest/developerguide/efs-volumes.html)