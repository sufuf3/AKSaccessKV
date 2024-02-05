export RESOURCE_GROUP="kvrg"
export LOCATION="eastus"
export SERVICE_ACCOUNT_NAMESPACE="default"
export SERVICE_ACCOUNT_NAME="csi-wi-sa"
export SUBSCRIPTION="$(az account show --query id --output tsv)"
export UAMI="sjUAMI4csi"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="sjFI4csi"
export CLUSTER_NAME="kvaks"
export KEYVAULT_NAME="sjkvcsitw"

# Create a managed identity
az identity create --name "${UAMI}" --resource-group "${RESOURCE_GROUP}"
export UAMI_ID=$(az identity show --name "${UAMI}" --resource-group "${RESOURCE_GROUP}" --query id)
export NODE_RESOURCE_GROUP=$(az aks show -g "${RESOURCE_GROUP}" -n "${CLUSTER_NAME}" --query nodeResourceGroup -o tsv)
export VMSS_NAME=$(az vmss list -g "${NODE_RESOURCE_GROUP}" --query [0].name -o tsv)
az vmss identity assign -g "${NODE_RESOURCE_GROUP}" -n "${VMSS_NAME}" --identities "${UAMI_ID}"

export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${UAMI}" --query 'clientId' -o tsv)"
export KEYVAULT_SCOPE=$(az keyvault show --name $KEYVAULT_NAME --query id -o tsv)
az role assignment create --role "Key Vault Administrator" --assignee $USER_ASSIGNED_CLIENT_ID --scope $KEYVAULT_SCOPE

# Create Kubernetes service account
az aks get-credentials -n "${CLUSTER_NAME}" -g "${RESOURCE_GROUP}"

export KV_IDENTITY_TENANT=$(az keyvault show --name "${KEYVAULT_NAME}" --query "properties.tenantId")
sed -i -e "s/USER_ASSIGNED_CLIENT_ID/${USER_ASSIGNED_CLIENT_ID}/g" ./SecretProviderClass.yaml
sed -i -e "s/KEYVAULT_NAME/${KEYVAULT_NAME}/g" ./SecretProviderClass.yaml
sed -i -e "s/IDENTITY_TENANT/${KV_IDENTITY_TENANT}/g" ./SecretProviderClass.yaml
kubectl apply -f ./SecretProviderClass.yaml

# Deploy your application
kubectl apply -f ./deployment.yaml