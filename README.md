# Azure AKS lab infrastructure

Terraform infrastructure for my Azure AKS lab, deployed in the resource group `hmezouarRG` in France Central.

## What is created

- VNet and AKS subnet
- one-node AKS lab cluster with Azure CNI Overlay and Cilium
- Azure Disk CSI and snapshot support for the PostgreSQL PVC
- Workload Identity and Key Vault CSI integration
- Basic ACR
- new Azure Files SMB share for employees
- Azure Backup for AKS, scoped to namespace `database`
- separate storage account/container for Terraform remote state

## Why Azure Disk and Azure Files both appear

PostgreSQL persists its data on an Azure Managed Disk created dynamically by a Kubernetes PVC using `disk.csi.azure.com`. Azure Disk is block storage and `ReadWriteOnce` is appropriate for a single PostgreSQL pod.

The employee share is a separate requirement. It uses Azure Files SMB because employee devices need shared access from Windows, macOS and Linux. PostgreSQL does not use Azure Files.

## 1. Bootstrap remote state

Authenticate with Azure CLI, then run:

```powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -out=bootstrap.tfplan
terraform -chdir=bootstrap apply bootstrap.tfplan
terraform -chdir=bootstrap output -raw backend_init_command
```

The bootstrap creates the dedicated storage account and container used by the Terraform remote backend.

Run the printed backend initialization command from the repository root.

## 2. Configure inputs

```powershell
Copy-Item environments/lab.tfvars.example environments/lab.tfvars
```

`lab.tfvars` is intentionally ignored. Set `employee_group_object_id` when the Entra group exists. Never put a password, storage key, kubeconfig, SAS token, or service-principal secret in this file.

## 3. Review infrastructure

```powershell
terraform fmt -recursive
terraform validate
terraform plan -var-file=environments/lab.tfvars -out=main.tfplan
```

Deployment is deliberately manual:

```powershell
terraform apply main.tfplan
```

## 4. Application-repository contract

The `azure-aks-app` repository should create:

- namespace `database`
- ServiceAccount `postgres-workload`, annotated with output `postgres_workload_identity_client_id`
- `SecretProviderClass` targeting output `key_vault_name`
- PostgreSQL StatefulSet using `POSTGRES_PASSWORD_FILE`
- StorageClass/PVC with provisioner `disk.csi.azure.com`, SKU `StandardSSD_LRS`, and access mode `ReadWriteOnce`
- Argo CD Application with automated sync, self-heal, and prune

## AZ-104 learning map

| Topic | Where to study it here |
|---|---|
| Resource groups | resource organization and deployment scope |
| VNets/subnets | `modules/network` |
| Managed identities/RBAC | AKS, ACR pull, Key Vault and backup role assignments |
| Storage | Blob remote state, Azure Files SMB, Azure Managed Disk via CSI |
| Data protection | Backup Vault, policy, extension, snapshots and restore testing |
| Governance | tags, policy discovery, least privilege and plan review |

## Important recovery test

After application deployment, insert a recognizable row into PostgreSQL, run or wait for an AKS backup, restore into a different namespace, and prove the row exists. A successful backup job without a restore test is not enough evidence of recoverability.
