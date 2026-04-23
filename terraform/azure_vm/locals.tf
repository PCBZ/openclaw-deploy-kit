locals {
  openclaw_json_content = templatefile("${path.module}/openclaw.json.tpl", {
    openclaw_gateway_token = var.openclaw_gateway_token
    openrouter_api_key     = var.openrouter_api_key
    brave_api_key          = var.brave_api_key
    telegram_bot_token     = var.telegram_bot_token
    slack_app_token        = var.slack_app_token
    slack_bot_token        = var.slack_bot_token
    slack_enabled          = var.slack_app_token != "" && var.slack_bot_token != ""
  })

  bootstrap_vars = {
    openrouter_api_key       = var.openrouter_api_key
    telegram_bot_token       = var.telegram_bot_token
    openclaw_gateway_token   = var.openclaw_gateway_token
    brave_api_key            = var.brave_api_key
    swap_size                = var.swap_size
    openclaw_memory_limit_mb = var.openclaw_memory_limit_mb
    approve_operator_script  = file("${path.module}/approve_operator_approvals.py")
    openclaw_json_content    = local.openclaw_json_content
  }

  common_tags = {
    Environment = "Production"
    Application = "OpenClaw"
  }
}
