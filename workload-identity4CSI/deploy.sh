export RESOURCE_GROUP="kvrg"
export LOCATION="eastus"
export SERVICE_ACCOUNT_NAMESPACE="default"
export SERVICE_ACCOUNT_NAME="csi-wi-sa"
export SUBSCRIPTION="$(az account show --query id --output tsv)"
export UAMI="sjUAMI"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="sjFI4csi"
export CLUSTER_NAME="kvaks"
export KEYVAULT_NAME="sjkvcsitw"

# Create a managed identity
az identity create --name "${UAMI}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --subscription "${SUBSCRIPTION}"
export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${UAMI}" --query 'clientId' -o tsv)"
export IDENTITY_TENANT=$(az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query identity.tenantId -o tsv)
export KEYVAULT_SCOPE=$(az keyvault show --name $KEYVAULT_NAME --query id -o tsv)
az role assignment create --role "Key Vault Administrator" --assignee $USER_ASSIGNED_CLIENT_ID --scope $KEYVAULT_SCOPE

# Establish federated identity credential
export AKS_OIDC_ISSUER="$(az aks show -n "${CLUSTER_NAME}" -g "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" -o tsv)"
az identity federated-credential create --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} --identity-name "${UAMI}" --resource-group "${RESOURCE_GROUP}" --issuer "${AKS_OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange

# Create Kubernetes service account
az aks get-credentials -n "${CLUSTER_NAME}" -g "${RESOURCE_GROUP}"

sed -i -e "s/USER_ASSIGNED_CLIENT_ID/${USER_ASSIGNED_CLIENT_ID}/g" ./sa.yaml
sed -i -e "s/SERVICE_ACCOUNT_NAMESPACE/${SERVICE_ACCOUNT_NAMESPACE}/g" ./sa.yaml
sed -i -e "s/SERVICE_ACCOUNT_NAME/${SERVICE_ACCOUNT_NAME}/g" ./sa.yaml
kubectl apply -f ./sa.yaml

export KV_IDENTITY_TENANT=$(az keyvault show --name "${KEYVAULT_NAME}" --query "properties.tenantId")
sed -i -e "s/USER_ASSIGNED_CLIENT_ID/${USER_ASSIGNED_CLIENT_ID}/g" ./SecretProviderClass.yaml
sed -i -e "s/KEYVAULT_NAME/${KEYVAULT_NAME}/g" ./SecretProviderClass.yaml
sed -i -e "s/IDENTITY_TENANT/${KV_IDENTITY_TENANT}/g" ./SecretProviderClass.yaml
kubectl apply -f ./SecretProviderClass.yaml

# Deploy your application
sed -i -e "s/SERVICE_ACCOUNT_NAME/${SERVICE_ACCOUNT_NAME}/g" ./deployment.yaml
kubectl apply -f ./deployment.yaml