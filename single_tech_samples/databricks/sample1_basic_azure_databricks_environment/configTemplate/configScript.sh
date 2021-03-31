#!/bin/bash -e

DEPLOYMENT_PREFIX=${DEPLOYMENT_PREFIX:-}
AZURE_RESOURCE_GROUP_NAME=${AZURE_RESOURCE_GROUP_NAME:-}
DEPLOY_PRINCIPAL_ID=${DEPLOY_PRINCIPAL_ID:-}

# Variables
keyVaultName="${DEPLOYMENT_PREFIX}akv01"
storageAccountName="${DEPLOYMENT_PREFIX}asa01"
adbWorkspaceName="${DEPLOYMENT_PREFIX}adb01"
scopeName="storage_scope"
#
echo "Retrieving keys from storage account"
storageKeys=$(az storage account keys list --resource-group "$AZURE_RESOURCE_GROUP_NAME" --account-name "$storageAccountName")
storageAccountKey1=$(echo "$storageKeys" | jq -r '.[0].value')
storageAccountKey2=$(echo "$storageKeys" | jq -r '.[1].value')

appId="$(az ad sp show --id "$DEPLOY_PRINCIPAL_ID" --query "appId" --output tsv)"
az keyvault set-policy --name "$keyVaultName" --spn "$appId" --secret-permissions get list set

echo "Storing keys in key vault"
az keyvault secret set -n "StorageAccountKey1" --vault-name "$keyVaultName" --value "$storageAccountKey1" --output none
az keyvault secret set -n "StorageAccountKey2" --vault-name "$keyVaultName" --value "$storageAccountKey2" --output none
echo "Successfully stored secrets StorageAccountKey1 and StorageAccountKey2"

az extension add --name databricks --yes --output none
# # Create ADB secret scope backed by Key Vault
adbGlobalToken=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --output json | jq -r .accessToken)
echo "Got adbGlobalToken=\"${adbGlobalToken:0:20}...${adbGlobalToken:(-20)}\""
azureApiToken=$(az account get-access-token --resource https://management.core.windows.net/ --output json | jq -r .accessToken)
echo "Got azureApiToken=\"${azureApiToken:0:20}...${azureApiToken:(-20)}\""

keyVaultId=$(az keyvault show --name "$keyVaultName" --query "id" --output tsv)
keyVaultUri=$(az keyvault show --name "$keyVaultName" --query "properties.vaultUri" --output tsv)

adbId=$(az databricks workspace show --resource-group "$AZURE_RESOURCE_GROUP_NAME" --name "$adbWorkspaceName" --query id --output tsv)
adbWorkspaceUrl=$(az databricks workspace show --resource-group "$AZURE_RESOURCE_GROUP_NAME" --name "$adbWorkspaceName" --query workspaceUrl --output tsv)

authHeader="Authorization: Bearer $adbGlobalToken"
adbSPMgmtToken="X-Databricks-Azure-SP-Management-Token:$azureApiToken"
adbResourceId="X-Databricks-Azure-Workspace-Resource-Id:$adbId"

createSecretScopePayload="{
  \"scope\": \"$scopeName\",
  \"scope_backend_type\": \"AZURE_KEYVAULT\",
  \"backend_azure_keyvault\":
  {
    \"resource_id\": \"$keyVaultId\",
    \"dns_name\": \"$keyVaultUri\"
  },
  \"initial_manage_principal\": \"users\"
}"
echo "$createSecretScopePayload" | curl -sS -X POST -H "$authHeader" -H "$adbSPMgmtToken" -H "$adbResourceId" \
    --data-binary "@-" "https://${adbWorkspaceUrl}/api/2.0/secrets/scopes/create"

echo "$createSecretScopePayload"
az keyvault delete-policy --name "$keyVaultName" --spn "$appId"

sleep 600s
