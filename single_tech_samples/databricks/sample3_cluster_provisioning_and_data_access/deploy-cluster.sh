#!/usr/bin/env bash

DEPLOYMENT_PREFIX=${DEPLOYMENT_PREFIX:-}
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID:-}
AZURE_RESOURCE_GROUP_NAME=${AZURE_RESOURCE_GROUP_NAME:-}
AZURE_RESOURCE_GROUP_LOCATION=${AZURE_RESOURCE_GROUP_LOCATION:-}
CLUSTER_CONFIG=${CLUSTER_CONFIG:-}

if [[ -z "$DEPLOYMENT_PREFIX" ]]; then
    echo "No deployment prefix [DEPLOYMENT_PREFIX] specified."
    exit 1
fi
if [[ -z "$AZURE_SUBSCRIPTION_ID" ]]; then
    echo "No Azure subscription id [AZURE_SUBSCRIPTION_ID] specified."
    exit 1
fi
if [[ -z "$AZURE_RESOURCE_GROUP_NAME" ]]; then
    echo "No Azure resource group [AZURE_RESOURCE_GROUP_NAME] specified."
    exit 1
fi
if [[ -z "$AZURE_RESOURCE_GROUP_LOCATION" ]]; then
    echo "No Azure resource group [AZURE_RESOURCE_GROUP_LOCATION] specified."
    exit 1
fi
if [[ -z "$CLUSTER_CONFIG" ]]; then
    echo "No Azure resource group [CLUSTER_CONFIG] specified, use default ./cluster-config.example.json"
    CLUSTER_CONFIG="./cluster-config.example.json"
fi

# Get deployment key from Key Vault

keyVaultName="${DEPLOYMENT_PREFIX}akv01"
adbDeploymentTokenName="DatabricksDeploymentToken"

echo "Getting secret $adbDeploymentTokenName from Azure Key Vault $keyVaultName"
adbToken=$(az keyvault secret show --name "$adbDeploymentTokenName" --vault-name "$keyVaultName" --query "value" --output tsv)

# Get WorkspaceUrl from Azure Databricks

adbName="${DEPLOYMENT_PREFIX}adb01"
echo "Getting WorkspaceUrl from Azure Databricks instance $adbName"
adbWorkspaceUrl=$(az databricks workspace show --resource-group "$AZURE_RESOURCE_GROUP_NAME" --name "$adbName" --query workspaceUrl --output tsv)

# Deploy the cluster based on the configuration file
# Note: you can also use the Databricks CLI to deploy
adbAuthHeader="Authorization: Bearer $adbToken"

echo "Deploying cluster with configuration $CLUSTER_CONFIG"
jq < "$CLUSTER_CONFIG"
clusterName=$(jq -r '.cluster_name' < "$CLUSTER_CONFIG")

echo "Creating cluster \"$clusterName\" in Azure Databricks"

currentClusterCount=$(curl -sS -X GET -H "$adbAuthHeader" "https://${adbWorkspaceUrl}/api/2.0/clusters/list" | jq "[ .clusters | .[]? | select(.cluster_name == \"${clusterName}\") ] | length")
if [[ "$currentClusterCount" -gt "0" ]]; then
    echo "Cluster \"$clusterName\" already exists in Azure Databricks, updating..."
    clusterIdToUpdate=$(curl -sS -X GET -H "$adbAuthHeader" "https://${adbWorkspaceUrl}/api/2.0/clusters/list" | jq -r "[ .clusters | .[] | select(.cluster_name == \"${clusterName}\") ][0].cluster_id")
    echo "Updating cluster \"$clusterIdToUpdate\""
    jq -r ".cluster_id = \"$clusterIdToUpdate\"" < "$CLUSTER_CONFIG" | \
      curl -sS -X POST -H "$adbAuthHeader" --data-binary "@-" "https://${adbWorkspaceUrl}/api/2.0/clusters/edit" | jq
    echo "Cluster \"$clusterName\" is being updated."
else
    curl -sS -X POST -H "$adbAuthHeader" --data-binary "@${CLUSTER_CONFIG}" "https://${adbWorkspaceUrl}/api/2.0/clusters/create" | jq
    echo "Cluster \"$clusterName\" is being created."
fi
