# Azure Function Deployment Guide for OpenClaw

完全自动化的 OpenClaw 部署，使用 Azure Function 处理 Webhook 并自动管理 ACI。

## 架构

```
Telegram/Slack Webhook
         ↓
    Azure Function
  (webhook handler)
         ↓
   检查 ACI 状态
   ├→ 如果停止 → 启动 ACI (30-60s)
   └→ 如果运行 → 直接继续
         ↓
    转发消息到 ACI
  (OpenClaw Gateway)
         ↓
      处理消息
   (读/写 NAS 存储)
         ↓
   返回响应到用户
         ↓
  30 分钟无活动
         ↓
  Timer Function 停止 ACI
```

## 成本

```
使用场景: 每天 5 条消息，每条 2 分钟处理

ACI 运行成本：          ~¥36/月（2CPU/4GB 常驻）
    ↓ 优化后
ACI 运行成本：          ~$2/月（按需启停）
Storage (File Share)：   ~$0.5/月
Function App：          ~$0（消费计划，免费额度）
────────────────────────────────────
总计：                 ~$2.50/月 ✨（省 92%）
```

## 部署前提

✅ 完成了 Terraform 配置（main.tf, variables.tf 等）
✅ 已创建 Storage Account for ACI 数据
✅ 已创建 Function App Infrastructure

## 配置项

在 `terraform.tfvars` 中可以配置：

```hcl
# 自动停止空闲 ACI 的时间（分钟）
idle_timeout_minutes = 30  # 改为你想要的分钟数
```

这个值会自动传递给 Function App，控制多久没有活动就停止 ACI。

## 部署步骤

### Step 1: Terraform 部署基础设施

```bash
cd terraform/azure
direnv allow
terraform apply
```

应看到输出:
```
Outputs:

function_app_name = "openclaw-func-001"
function_app_default_hostname = "openclaw-func-001.azurewebsites.net"
eci_intranet_ip = "10.x.x.x"
```

### Step 2: 获取 Publish Profile

```bash
# 获取 Function App 的 publish profile
az functionapp deployment list-publishing-credentials \
  --name openclaw-func-001 \
  --resource-group openclaw-rg \
  --query publishingPassword \
  -o tsv
```

### Step 3: 部署函数代码

选项 A：使用 Azure CLI

```bash
cd terraform/azure/function

# 创建 function.json (for webhook handler)
cat > webhook/function.json << 'EOF'
{
  "scriptFile": "../webhook.py",
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["post"],
      "route": "webhook"
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ]
}
EOF

# 创建 function.json (for auto-stop timer)
cat > auto-stop/function.json << 'EOF'
{
  "scriptFile": "../auto_stop.py",
  "bindings": [
    {
      "name": "mytimer",
      "type": "timerTrigger",
      "direction": "in",
      "schedule": "0 */30 * * * *"
    }
  ]
}
EOF

# 部署
func azure functionapp publish openclaw-func-001
```

选项 B：使用 VS Code Azure Functions 扩展

1. 打开 VS Code
2. 装 "Azure Functions" 扩展
3. Sign in to Azure
4. Deploy to Function App

### Step 4: 配置 Webhook URL

获取 webhook URL:

```bash
# 查看 function url
az functionapp function show \
  --function-name webhook \
  --name openclaw-func-001 \
  --resource-group openclaw-rg \
  --query "invokeUrlTemplate"
```

输出示例:
```
https://openclaw-func-001.azurewebsites.net/api/webhook
```

**Telegram 配置**:

```bash
BOT_TOKEN="YOUR_BOT_TOKEN"
WEBHOOK_URL="https://openclaw-func-001.azurewebsites.net/api/webhook"

curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -d "url=${WEBHOOK_URL}"
```

**Slack 配置**:

1. 进入 Slack App Settings
2. Event Subscriptions → Enable Events
3. Request URL: `https://openclaw-func-001.azurewebsites.net/api/webhook`
4. Request URL Verification: Slack 会发送验证请求

### Step 5: 测试

发送一条消息:

```
你好，OpenClaw！
```

**观察**:

1. ACI 自动启动 (~30-60 秒)
2. 消息被处理
3. 收到回复
4. Function App 日志显示执行信息

查看日志:

```bash
# 实时日志
func start

# 或在 Azure Portal
# Function App → Functions → 查看 Monitor/Logs
```

### Step 6: 配置定时停止

Timer 已配置为每 30 分钟运行一次。

检查定时器:

```bash
# 查看 auto-stop 函数
az functionapp function show \
  --function-name auto-stop \
  --name openclaw-func-001 \
  --resource-group openclaw-rg
```

## 运维

### 查看实时日志

```bash
# Azure Portal 中
# → Function App → Functions → Monitor → 查看最近调用

# 或 CLI
az functionapp log tail \
  --name openclaw-func-001 \
  --resource-group openclaw-rg
```

### 手动停止 ACI (测试)

```bash
az container stop \
  --name openclaw-container \
  --resource-group openclaw-rg
```

### 手动启动 ACI (测试)

```bash
az container start \
  --name openclaw-container \
  --resource-group openclaw-rg
```

### 更新函数代码

```bash
cd terraform/azure/function

# 修改 webhook.py 或 auto_stop.py

# 重新部署
func azure functionapp publish openclaw-func-001
```

## 成本监控

```bash
# 在 Azure Portal
# → Cost Management + Billing
# → 查看每日成本
```

设置告警:

```bash
# Cost Alerts → 设置 $5/月 告警
```

## 常见问题

### Q1: Webhook 无法触发?

**排查**:
1. 检查 webhook URL 是否正确
2. 查看 Function App 日志
3. 测试: `curl -X POST https://openclaw-func-001.azurewebsites.net/api/webhook -d '{"test": true}'`

### Q2: ACI 没有启动?

**排查**:
1. 检查 Function App 身份认证 (IAM Role Assignment)
2. 查看 Function App 错误日志
3. 确认 ACI 权限

### Q3: 消息处理太慢?

**注意**: 第一条消息会因为冷启动慢 30-60 秒。这是正常的。

### Q4: NAS 数据丢失?

**排查**:
1. 检查 File Share 挂载是否正确
2. 查看 ACI 日志
3. 验证 `/root/.openclaw` 权限

## 下一步

- [ ] 测试 Telegram/Slack webhook
- [ ] 发送测试消息
- [ ] 监控成本（第一周）
- [ ] 调整 Timer 间隔（如需要）
- [ ] 实现高级活动追踪（可选）

## 高级：活动追踪

当前实现: 30 分钟后自动停止

改进方案 (需要额外实现):
1. 将最后活动时间存储在 Azure Storage Table / Cosmos DB
2. Webhook Handler 更新时间戳
3. Auto-stop 查询时间戳

```python
# 示例代码
from azure.data.tables import TableClient

def update_activity():
    client = TableClient.from_connection_string(...)
    entity = {
        'PartitionKey': 'openclaw',
        'RowKey': 'last_activity',
        'timestamp': time.time()
    }
    client.upsert_entity(entity)

def get_last_activity():
    client = TableClient.from_connection_string(...)
    entity = client.get_entity('openclaw', 'last_activity')
    return entity['timestamp']
```

## 支持

- [Azure Functions 文档](https://learn.microsoft.com/en-us/azure/azure-functions/)
- [Azure Container Instances 文档](https://learn.microsoft.com/en-us/azure/container-instances/)
- [Azure CLI 参考](https://learn.microsoft.com/en-us/cli/azure/)
