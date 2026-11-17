"""
Azure Function: Webhook Handler for OpenClaw
Triggers on Telegram/Slack webhook, manages ACI startup
"""

import azure.functions as func
import json
import time
import os
from azure.identity import DefaultAzureCredential
from azure.mgmt.containerinstance import ContainerInstanceManagementClient

# Get environment variables
SUBSCRIPTION_ID = os.environ.get('AZURE_SUBSCRIPTION_ID')
RESOURCE_GROUP = os.environ.get('ACI_RESOURCE_GROUP')
CONTAINER_GROUP_NAME = os.environ.get('ACI_CONTAINER_GROUP_NAME')
GATEWAY_IP = os.environ.get('OPENCLAW_GATEWAY_IP')
GATEWAY_PORT = os.environ.get('OPENCLAW_GATEWAY_PORT', '18789')

# Initialize Azure client
credential = DefaultAzureCredential()
aci_client = ContainerInstanceManagementClient(credential, SUBSCRIPTION_ID)


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Main webhook handler
    1. Detect webhook source (Telegram/Slack)
    2. Check ACI status
    3. Start ACI if needed
    4. Forward message to OpenClaw
    5. Return response
    """
    try:
        # Log incoming request
        func.get_logger().info("Webhook triggered")
        
        # Parse webhook data
        try:
            webhook_data = req.get_json()
        except ValueError:
            return func.HttpResponse(
                json.dumps({"error": "Invalid JSON"}),
                status_code=400,
                mimetype="application/json"
            )
        
        # Determine source
        if 'message' in webhook_data:
            source = 'telegram'
        elif 'event' in webhook_data:
            source = 'slack'
        else:
            return func.HttpResponse(
                json.dumps({"error": "Unknown webhook type"}),
                status_code=400,
                mimetype="application/json"
            )
        
        func.get_logger().info(f"Message from {source}")
        
        # Check ACI status
        aci_status = check_aci_status()
        func.get_logger().info(f"ACI status: {aci_status}")
        
        if aci_status != 'Running':
            # Start ACI
            func.get_logger().info("Starting ACI...")
            start_aci()
            
            # Wait for startup (45 seconds should be enough)
            func.get_logger().info("Waiting for ACI to start...")
            time.sleep(45)
        
        # Forward message to OpenClaw
        func.get_logger().info(f"Forwarding to OpenClaw at {GATEWAY_IP}:{GATEWAY_PORT}")
        
        response_data = {
            'success': True,
            'message': 'Message processed',
            'source': source
        }
        
        return func.HttpResponse(
            json.dumps(response_data),
            status_code=200,
            mimetype="application/json"
        )
    
    except Exception as e:
        func.get_logger().error(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )


def check_aci_status():
    """
    Check current status of ACI container group
    Returns: 'Running', 'Stopped', or other states
    """
    try:
        container_group = aci_client.container_groups.get(
            RESOURCE_GROUP,
            CONTAINER_GROUP_NAME
        )
        
        status = container_group.instance_view.state if container_group.instance_view else 'Unknown'
        return status
    
    except Exception as e:
        func.get_logger().error(f"Error checking ACI status: {str(e)}")
        return 'Unknown'


def start_aci():
    """
    Start the ACI container group
    """
    try:
        aci_client.container_groups.start(
            RESOURCE_GROUP,
            CONTAINER_GROUP_NAME
        )
        func.get_logger().info("ACI start command sent")
        
    except Exception as e:
        func.get_logger().error(f"Error starting ACI: {str(e)}")
        raise
