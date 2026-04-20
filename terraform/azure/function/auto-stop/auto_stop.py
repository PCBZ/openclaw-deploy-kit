"""
Azure Function: Auto-Stop Timer for OpenClaw
Triggered every 30 minutes, stops idle ACI
"""

import azure.functions as func
import os
import time
from azure.identity import DefaultAzureCredential
from azure.mgmt.containerinstance import ContainerInstanceManagementClient

# Environment variables
SUBSCRIPTION_ID = os.environ.get('AZURE_SUBSCRIPTION_ID')
RESOURCE_GROUP = os.environ.get('ACI_RESOURCE_GROUP')
CONTAINER_GROUP_NAME = os.environ.get('ACI_CONTAINER_GROUP_NAME')

# Initialize client
credential = DefaultAzureCredential()
aci_client = ContainerInstanceManagementClient(credential, SUBSCRIPTION_ID)

# Idle timeout (configurable via environment variable)
IDLE_TIMEOUT_MINUTES = int(os.environ.get('IDLE_TIMEOUT_MINUTES', '30'))
IDLE_TIMEOUT = IDLE_TIMEOUT_MINUTES * 60


def main(mytimer: func.TimerRequest) -> None:
    """
    Timer trigger: runs every 30 minutes
    Stops ACI if idle
    """
    try:
        func.get_logger().info("Auto-stop timer triggered")
        
        # Check ACI status
        aci_status = check_aci_status()
        func.get_logger().info(f"ACI status: {aci_status}")
        
        if aci_status == 'Running':
            # Check if idle
            if is_aci_idle():
                func.get_logger().info("ACI is idle, stopping...")
                stop_aci()
                func.get_logger().info("ACI stopped")
            else:
                func.get_logger().info("ACI still active, not stopping")
        else:
            func.get_logger().info(f"ACI is {aci_status}, no action needed")
    
    except Exception as e:
        func.get_logger().error(f"Error in auto-stop: {str(e)}")


def check_aci_status():
    """Get current ACI status"""
    try:
        container_group = aci_client.container_groups.get(
            RESOURCE_GROUP,
            CONTAINER_GROUP_NAME
        )
        
        status = container_group.instance_view.state if container_group.instance_view else 'Unknown'
        return status
    
    except Exception as e:
        func.get_logger().error(f"Error checking status: {str(e)}")
        return 'Unknown'


def is_aci_idle():
    """
    Check if ACI is idle
    Simplified: if no recent activity (in production, use proper activity tracking)
    """
    try:
        # In production, you would check:
        # - Database for last activity timestamp
        # - Application logs
        # - Custom metrics
        
        # For now, simplified: always consider it idle after 30min
        # In real deployment, implement proper activity tracking
        func.get_logger().info("Checking idleness - simplified logic")
        return True
    
    except Exception as e:
        func.get_logger().error(f"Error checking idleness: {str(e)}")
        return False


def stop_aci():
    """Stop the ACI container group"""
    try:
        aci_client.container_groups.stop(
            RESOURCE_GROUP,
            CONTAINER_GROUP_NAME
        )
        func.get_logger().info("ACI stop command sent")
    
    except Exception as e:
        func.get_logger().error(f"Error stopping ACI: {str(e)}")
        raise
