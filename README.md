# AWS HA Observability Stack (AWS Prometheus + Grafana + OpenTelemetry Collector)

> **A production-grade, highly available, open-source observability pipeline engineered on AWS using a strictly isolated, layered Terraform design pattern.**

---

## Table of Contents

* [About / Overview](https://www.google.com/search?q=%23about--overview)
* [Goals of the Repository](https://www.google.com/search?q=%23goals_of_the_repository)
* [AWS Well-Architected Framework Alignment](https://www.google.com/search?q=%23aws-well-architected-framework-alignment)
* [Site Reliability Engineering (SRE) Maturity](https://www.google.com/search?q=%23site-reliability-engineering-sre-maturity)
* [Architecture & Structural Layers](https://www.google.com/search?q=%23architecture--structural-layers)
* [Prerequisites](https://www.google.com/search?q=%23prerequisites)
* [Local Setup & Forking Instructions](https://www.google.com/search?q=%23local-setup--forking-instructions)
* [Deployment & Execution Steps](https://www.google.com/search?q=%23deployment--execution-steps)
* [Usage & Telemetry Verification](https://www.google.com/search?q=%23usage--telemetry-verification)
* [Monitoring & Maintenance](https://www.google.com/search?q=%23monitoring--maintenance)
* [Cleanup / Teardown](https://www.google.com/search?q=%23cleanup--teardown)
* [Contributing](https://www.google.com/search?q=%23contributing)
* [License](https://www.google.com/search?q=%23license)
* [References / Further Reading](https://www.google.com/search?q=%23references--further-reading)

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

* **`01-vpc-network`**: Allocates the base multi-AZ network block, setting up your public subnets, private subnets, internet gateways, and routing tables.
* **`02-security-groups`**: Establishes individual firewall boundaries, mapping traffic paths strictly between components.
* **`03-ecr-repositories`**: Configures clean, private Amazon Elastic Container Registries to store and manage custom container images.
* **`04-ecs-fargate-cluster`**: Provisions the shared serverless ECS container orchestration host layer.
* **`05-opentelemetry-collector`**: Deploys the core open telemetry collection pipeline daemon tasks.
* **`06-jaeger-tracing`**: Deploys the localized tracing engine instance.
* **`07-prometheus-ecs`**: Builds the core backend time-series database with underlying EFS file storage links.
* **`08-grafana-dashboards`**: Deploys the front-facing dashboard layer, using Route 53 and ACM to handle public domain mapping over HTTPS.

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
project_name = "sre-concepts"
region       = "us-east-1"
domain_name  = "yourdomain.com"

```

### Step 2: Sequential Phased Layer Deployment

Because subsequent modules rely on inputs from earlier layers, you must deploy the layers sequentially from the root directory (aws-prometheus-grafana-otel-collector/terraform).

Run the following commands:

```bash
# Initialize and Apply Phase 1: Core Networking
cd layers/01-vpc-network
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 01

# Initialize and Apply Phase 2: Security Rules Boundary
cd layers/02-security-groups
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 02

# Initialize and Apply Phase 3: Container Registries
cd layers/03-ecr-repositories
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 03

# Initialize and Apply Phase 4: Core Fargate Clusters
cd layers/04-ecs-fargate-cluster
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 04

# Initialize and Apply Phase 5: OpenTelemetry Collectors
cd layers/05-opentelemetry-collector
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 05

# Initialize and Apply Phase 6: Jaeger Tracing Backend
cd layers/06-jaeger-tracing
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 06

# Initialize and Apply Phase 7: Prometheus Target Engine
cd layers/07-prometheus-ecs
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 07

# Initialize and Apply Phase 8: Grafana Visualization Portals
cd layers/08-grafana-dashboards
terraform init
terraform plan -var-file="../../central.tfvars"
terraform apply -var-file="../../central.tfvars" -auto-approve
cd ../.. && ./sync-vars.sh 08

```

> **Note:** The `sync-vars.sh` helper utility runs after each deployment step. It extracts newly generated IDs (like Subnet IDs, Security Group IDs, or Target Group ARNs) and injects them into downstream variables files so subsequent modules can ingest them dynamically.

---

## Usage & Telemetry Verification

Once Layer 08 is fully deployed, all endpoints are verified and secured via HTTPS through Route 53 routing tables.

### 1. Accessing Your Core Portals

Open your web browser and navigate to your configured domain paths:

* **Grafana Visual UI:** `https://grafana.yourdomain.com` (Default login user: `admin` / Password: Check your `central.tfvars` configuration variables).
* **Prometheus Dashboard:** `https://prometheus.yourdomain.com`
* **Jaeger Ingest UI:** `https://jaeger.yourdomain.com`

### 2. Testing Your Pipeline End-to-End

To confirm that metric and trace payloads travel correctly across your network paths from application runtimes into your visualization dashboards, you can send a test payload from your terminal.

Execute a mock HTTP POST payload directly against your public application load balancer routing endpoint, targeting the OpenTelemetry receiver network hooks:

```bash
curl -i -X POST http://otel-collector.yourdomain.com:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [{"key": "service.name", "value": {"stringValue": "sre-sandbox-app"}}]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "heartbeat.ping.count",
          "sum": {
            "dataPoints": [{"asInt": "1"}],
            "aggregationTemporality": 1,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'

```

Verify the ingest pathway by logging into `https://prometheus.yourdomain.com` and querying the metric name `heartbeat_ping_count`.

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
# Terminate tracking layers and working dashboards
cd layers/08-grafana-dashboards && terraform destroy -var-file="../../central.tfvars" -auto-approve
cd ../07-prometheus-ecs && terraform destroy -var-file="../../central.tfvars" -auto-approve
cd ../06-jaeger-tracing && terraform destroy -var-file="../../central.tfvars" -auto-approve
cd ../05-opentelemetry-collector && terraform destroy -var-file="../../central.tfvars" -auto-approve

# Terminate clusters, repositories, and security rules
cd ../04-ecs-fargate-cluster && terraform destroy -var-file="../../central.tfvars" -auto-approve
cd ../03-ecr-repositories && terraform destroy -var-file="../../central.tfvars" -auto-approve
cd ../02-security-groups && terraform destroy -var-file="../../central.tfvars" -auto-approve

# Terminate base network
cd ../01-vpc-network && terraform destroy -var-file="../../central.tfvars" -auto-approve

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