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

`lab.tfvars` is intentionally ignored. Never put a password, storage key, kubeconfig, SAS token, or service-principal secret in this file.

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

## Employee file share

The `employees` Azure Files share uses SMB 3.1.1 and Microsoft Entra Kerberos. The Entra security group `employees-hmezouar` receives both `Storage File Data SMB Share Reader` and `Storage File Data SMB Share Contributor`, scoped directly to this file share. Access is then managed by adding or removing users in the group. No default share-level permission is granted to other identities.

The share can be reviewed in the Azure portal under the storage account, then **Data storage > File shares > employees**. Group access is visible under **Access control IAM > Role assignments**.

## Recovery verification

The database namespace is protected by Azure Backup every four hours with seven-day operational retention. The recovery test created a recognizable PostgreSQL row, produced an incremental recovery point and Azure Disk snapshot, then restored the workload into `database-restore` with its volume data.

The restored PostgreSQL pod reached `Running`, its 16 Gi PVC reached `Bound`, and `SELECT * FROM lab_check;` returned `azure-disk-persists`. The restore namespace has a Workload Identity federated credential so the restored pod can mount the Key Vault secret.

Useful verification commands:

```bash
kubectl get application postgresql -n argocd
kubectl get pod,pvc -n database
kubectl get pod,pvc -n database-restore
kubectl exec -n database-restore postgres-0 -- \
  psql -U postgres -d appdb -c "SELECT * FROM lab_check;"
```
