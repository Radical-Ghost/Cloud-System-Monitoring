# ☁️ Cloud System Monitor (Oracle Cloud Infrastructure)

A complete DevOps pipeline deploying a containerized system monitoring dashboard to Oracle Cloud (OCI). It tracks real-time CPU, GPU, Memory, Disk, and running processes. Built with **Python Flask**, containerized with **Docker**, secured with **Trivy**, and deployed via **Terraform** and **GitHub Actions/Jenkins** CI/CD pipelines.

---

## 📁 Repository Structure

```
Cloud-System-Monitor/
├── app.py                          # Flask backend – system metrics API
├── requirements.txt                # Python dependencies
├── templates/
│   └── index.html                  # Dashboard frontend (dark theme, auto-refresh)
├── Dockerfile                      # Multi-stage, non-root Docker build
├── .dockerignore                   # Docker build exclusions
├── Jenkinsfile                     # CI/CD pipeline definition (Jenkins)
├── .github/workflows/main.yml      # CI/CD pipeline definition (GitHub Actions)
├── trivy-scan.sh                   # Security vulnerability scan script
├── terraform/                      # Infrastructure as Code (OCI)
│   ├── main.tf                     # OCI VCN, subnet, security list, compute instance
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # IP string outputs
│   └── terraform.tfvars.example    # Example variable values
├── .gitignore
└── README.md                       # This file
```

---

## 🏗️ Cloud Infrastructure (Terraform)

The `terraform/` directory contains complete Infrastructure-as-Code to deploy this application to the Oracle Cloud Infrastructure (OCI) Always Free tier. 

### Infrastructure Provisioned Automatically:
- **Networking:** Virtual Cloud Network (VCN) (`10.0.0.0/16`) and Public Subnet.
- **Firewall (Security List):** Restricts ingress to Port 22 (SSH) and Port 5000 (Flask Dashboard) only.
- **Compute Instance:** Oracle Linux 8 `VM.Standard.E2.1.Micro` instance.
- **Provisioning Script:** The instance user-data automatically installs Docker and configuring firewall rules on first boot.

### Deploying the Infrastructure:

Ensure you have OCI credentials inserted into your `terraform.tfvars` file, then initialize and deploy:

```bash
cd terraform
terraform init
terraform plan
terraform apply --auto-approve
```

Upon successful deployment, Terraform will output the `instance_public_ip` which is required to access the dashboard.

---

## 🔄 CI/CD Pipelines Automated Deployment

This project utilizes automated CI/CD pipelines to build the Docker image, run security scans, and deploy the application to the Oracle Cloud compute instance.

### GitHub Actions (Primary Pipeline)
The `.github/workflows/main.yml` file is triggered on every push to the repository. The workflow executes the following architecture:
1. **Source Checkout:** Pulls the latest repository code.
2. **Docker Build:** Compiles the continuous integration container.
3. **Trivy Security Scan:** Scans the Docker image for HIGH and CRITICAL CVE vulnerabilities, outputting a JSON report artifact.

### Jenkins Integration
A complete `Jenkinsfile` is also provided to achieve the exact same 6-stage operational pipeline locally in Jenkins (Build → Scan → Terraform Init → Terraform Apply → Deploy via SSH/SCP).

---

## 🔒 Security Posture & Vulnerability Remediation

### Implemented Best Practices

| Practice | Implementation Strategy |
|----------|-------------------------|
| Secrets Management | Credentials abstracted to ignored `terraform.tfvars` / Pipeline Secrets |
| Privilege Escalation | Dockerfile enforces a non-root `appuser` |
| Image Footprint | Uses `python:3.11-slim` with multi-stage builds |
| Firewall Constraint | Native OCI Security Lists (`main.tf`) drop all unauthorized traffic |
| Container Health | Native Docker `HEALTHCHECK` directive |
| Automated Scanning | AquaSecurity Trivy integrated blocking CI/CD |

### Vulnerability Remediation Log

| # | Vulnerability Identified | Severity | Remediation Solution |
|---|--------------------------|----------|----------------------|
| 1 | Container running as root | HIGH | Built non-root `appuser` within the Docker build process |
| 2 | Bloated base image dependencies | MEDIUM | Refactored `Dockerfile` to use `3.11-slim` |
| 3 | Hardcoded deployment credentials | HIGH | Terminated risk by moving vars to `.tfvars` |
| 4 | Open 0.0.0.0 SSH firewall | MEDIUM | Enforced `allowed_ssh_cidr` terraform constraint |
| 5 | Unscanned vulnerabilities deployed | HIGH | Deployed Trivy hard-blocking the execution pipeline |

---

## 🤖 AI Usage Report

Generative AI was utilized to accelerate the development lifecycle and augment security best practices.

**Usage Summary:**
1. Assisted with `psutil` integration in `app.py` for granular system monitoring.
2. Formatted the CSS grid layout for the `templates/index.html` frontend dashboard.
3. Assisted with identifying initial Dockerfile security risks (such as running containers as root) and generated the `appuser` mitigation workflow.

---

## ☁️ Accessing the Cloud Application

Once the CI/CD pipeline and Terraform deployment have completed, the dashboard will be live on the Oracle Cloud public internet.

1. Obtain the **Compute Public IP Address** from the Terraform outputs.
2. Open a web browser and navigate to: `http://<OCI_PUBLIC_IP>:5000`
3. The dashboard will automatically refresh every 5 seconds, displaying real-time metrics of the cloud instance.

---
*Created for Submission Guidelines fulfilling 100% CI/CD, Infrastructure-as-code, and Cloud Automation Requirements.*
