# OpenClaw on Azure ACI Deployment Guide

## Prerequisites

1. **Azure Account**: Azure Student subscription
2. **Azure CLI**: [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
3. **Terraform**: Installed Terraform CLI
4. **Docker & Docker Compose**: For local testing (optional)
5. **OpenClaw API Keys**: From [docs.openclaw.ai](https://docs.openclaw.ai)

## Step 1: Local Testing with Docker Compose (Optional)

Before deploying to Azure, test locally:

```bash
# Navigate to azure directory
cd terraform/azure

# Copy .env from project root
cp ../../.env .

# Start with docker-compose
docker-compose up -d

# Check logs
docker-compose logs -f openclaw-gateway

# Test health endpoint
curl http://localhost:18789/healthz

# Stop when done
docker-compose down
```

## Step 2: Set Up Azure Authentication

### Create Service Principal

```bash
az login
az account show

# Create Service Principal for Terraform
az ad sp create-for-rbac --name "openclaw-terraform" --role Contributor
```

Output contains:
- `appId` → `client_id`
- `password` → `client_secret`  
- `tenant` → `tenant_id`

Get Subscription ID:
```bash
az account show --query id -o tsv
```

### Configure terraform.tfvars

```bash
cd terraform/azure
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in **Azure-only settings** (no API keys needed here):
```hcl
subscription_id = "YOUR_SUBSCRIPTION_ID"
client_id       = "YOUR_CLIENT_ID"
client_secret   = "YOUR_CLIENT_SECRET"
tenant_id       = "YOUR_TENANT_ID"
```

### Load API keys from .env (via direnv)

Install and enable `direnv`:
```bash
# Install direnv (https://direnv.net/docs/installation.html)
# macOS:
brew install direnv

# Then enable it
direnv allow

# Now every time you cd into this directory, .env will be loaded automatically
cd terraform/azure
# direnv: loading .envrc (loads all API keys from ../../.env)
```

Or manually load before terraform:
```bash
source ../../.env
export TF_VAR_openrouter_api_key=$OPENROUTER_API_KEY
export TF_VAR_telegram_bot_token=$TELEGRAM_BOT_TOKEN
export TF_VAR_openclaw_gateway_token=$OPENCLAW_GATEWAY_TOKEN
export TF_VAR_brave_api_key=$BRAVE_API_KEY
export TF_VAR_telegram_owner_id=$TELEGRAM_OWNER_ID
export TF_VAR_slack_app_token=$SLACK_APP_TOKEN
export TF_VAR_slack_bot_token=$SLACK_BOT_TOKEN
```

## Step 3: Configure OpenClaw API Keys

**API Keys are loaded from `.env` file** — no need to put them in terraform.tfvars!

If using **direnv** (recommended):
```bash
direnv allow
# All API keys from ../../.env are now available as TF_VAR_ environment variables
```

If **not using direnv**, manually export before running terraform:
```bash
source ../../.env
export TF_VAR_openrouter_api_key=$OPENROUTER_API_KEY
export TF_VAR_telegram_bot_token=$TELEGRAM_BOT_TOKEN
export TF_VAR_openclaw_gateway_token=$OPENCLAW_GATEWAY_TOKEN
export TF_VAR_brave_api_key=$BRAVE_API_KEY
export TF_VAR_telegram_owner_id=$TELEGRAM_OWNER_ID
export TF_VAR_slack_app_token=$SLACK_APP_TOKEN
export TF_VAR_slack_bot_token=$SLACK_BOT_TOKEN
```

## Step 4: Adjust Resource Configuration (Optional)

Adjust based on Azure Student quota:

```hcl
# CPU and memory configuration (must be compatible)
# Valid combinations: (0.5 CPU, 0.5-1.5 GB) | (1 CPU, 1-3.5 GB) | (1.5 CPU, 1.5-4 GB) | (2 CPU, 2-8 GB)
cpu_cores = 1
memory_gb = 1.5

# 位置（查询可用地点）
location = "eastus"  # or canadaeast, westus2, etc.

# 唯一的 DNS 名称
dns_name_label = "openclaw-aci-unique-12345"
```

查询可用位置：
```bash
az provider show --namespace Microsoft.ContainerInstance --query "resourceTypes[?resourceType=='containerGroups'].locations" -o tsv
```

## 步骤 5: 部署

```bash
cd terraform/azure

# 初始化 Terraform
terraform init

# 验证配置
terraform plan

# 应用配置
terraform apply
```

## 步骤 6: 访问容器

### 查看输出信息

```bash
terraform output
```

输出示例：
```
public_ip = "20.91.234.123"
fqdn = "openclaw-aci-unique.eastus.azurecontainer.io"
gateway_url = "http://openclaw-aci-unique.eastus.azurecontainer.io:18789"
```

### 访问 Gateway

```bash
curl http://<FQDN>:18789/status
```

### 查看容器日志

```bash
RESOURCE_GROUP="openclaw-rg"
CONTAINER_GROUP="openclaw-container"

# 实时查看日志
az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_GROUP --follow

# 查看一次日志
az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_GROUP
```

### 进入容器调试（可选）

```bash
# 执行命令
az container exec --resource-group $RESOURCE_GROUP --name $CONTAINER_GROUP --exec-command /bin/bash
```

## 成本考虑

Azure Student 账户通常有 $100 额度。ACI 按秒计费（大约 $0.0015/GB/小时）：

- 1 CPU + 1 GB 内存：~$0.01-0.02/小时
- 持续运行一个月（720小时）：~$10-15

## 清理资源

```bash
terraform destroy
```

或者手动清理：
```bash
az group delete --name openclaw-rg
```

## 常见问题

### Q: 如何更新容器镜像？

```bash
# 重新构建镜像
docker build -t openclaw:latest .

# 推送到 ACR 或 Docker Hub
docker push $REGISTRY_URL/openclaw:latest

# 重新部署（Terraform 会更新）
terraform apply
```

### Q: 如何查看容器是否正常运行？

```bash
# 检查容器状态
az container show --resource-group openclaw-rg --name openclaw-container

# 查看日志
az container logs --resource-group openclaw-rg --name openclaw-container --follow
```

### Q: Azure Student 支持 ACI 吗？

是的，ACI 是标准 Azure 服务，受 Student 订阅支持。注意配额限制和成本。

## 相关资源

- [Azure Container Instances 文档](https://learn.microsoft.com/en-us/azure/container-instances/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure 学生账户](https://azure.microsoft.com/en-us/free/students/)
