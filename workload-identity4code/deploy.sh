export RESOURCE_GROUP="kvrg"
export LOCATION="eastus"
export SERVICE_ACCOUNT_NAMESPACE="default"
export SERVICE_ACCOUNT_NAME="workload-identity-sa"
export SUBSCRIPTION="$(az account show --query id --output tsv)"
export USER_ASSIGNED_IDENTITY_NAME="sjUAIdentity"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="sjFIdentity"
export AKS_NAME="kvaks"
export KEYVAULT_NAME="sjkvtw"

# Create a managed identity
az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --subscription "${SUBSCRIPTION}"
export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' -o tsv)"
az keyvault set-policy --name "${KEYVAULT_NAME}" --secret-permissions get --spn "${USER_ASSIGNED_CLIENT_ID}"

# Create Kubernetes service account
az aks get-credentials -n "${AKS_NAME}" -g "${RESOURCE_GROUP}"

sed -i -e "s/USER_ASSIGNED_CLIENT_ID/${USER_ASSIGNED_CLIENT_ID}/g" ./sa.yaml
sed -i -e "s/SERVICE_ACCOUNT_NAMESPACE/${SERVICE_ACCOUNT_NAMESPACE}/g" ./sa.yaml
sed -i -e "s/SERVICE_ACCOUNT_NAME/${SERVICE_ACCOUNT_NAME}/g" ./sa.yaml

kubectl apply -f ./sa.yaml


# Establish federated identity credential
export AKS_OIDC_ISSUER="$(az aks show -n "${AKS_NAME}" -g "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" -o tsv)"
az identity federated-credential create --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${AKS_OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange

# Deploy your application
sed -i -e "s/SERVICE_ACCOUNT_NAME/${SERVICE_ACCOUNT_NAME}/g" ./deployment.yaml
kubectl apply -f ./deployment.yaml