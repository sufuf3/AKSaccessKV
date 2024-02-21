export RESOURCE_GROUP="kvrg"
export LOCATION="eastus"
export SERVICE_ACCOUNT_NAMESPACE="default"
export SERVICE_ACCOUNT_NAME="csi-wi-sa"
export SUBSCRIPTION="$(az account show --query id --output tsv)"
export UAMI="sjUAMI4csi"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="sjFI4csi"
export CLUSTER_NAME="kvaks"
export KEYVAULT_NAME="sjkvtw"

# az vmss update -g $VMSSRG -n $VMSSNAME --set identity.type='SystemAssigned' identity.userAssignedIdentities=null
# az vmss identity show -g $VMSSRG -n $VMSSNAME -o yaml

export AZURE_CLIENT_ID=$(az ad sp list --display-name ${SPNAME} --query [0].appId -o tsv)
export KEYVAULT_RESOURCE_GROUP="kvrg"

echo "enter VMSS RG: "
read VMSSRG
echo "enter VMSS NAME: "
read VMSSNAME
export VMSS_PRINCIPAL_ID=$(az vmss identity show -g $VMSSRG -n $VMSSNAME --query "principalId" -o tsv)

az keyvault set-policy -n $KEYVAULT_NAME --key-permissions get --object-id $VMSS_PRINCIPAL_ID
az keyvault set-policy -n $KEYVAULT_NAME --secret-permissions get --object-id $VMSS_PRINCIPAL_ID
az keyvault set-policy -n $KEYVAULT_NAME --certificate-permissions get --object-id $VMSS_PRINCIPAL_ID

# Create Kubernetes service account
az aks get-credentials -n "${CLUSTER_NAME}" -g "${RESOURCE_GROUP}"

export KV_IDENTITY_TENANT=$(az keyvault show --name "${KEYVAULT_NAME}" --query "properties.tenantId")
sed -i -e "s/KEYVAULT_NAME/${KEYVAULT_NAME}/g" ./SecretProviderClass.yaml
sed -i -e "s/IDENTITY_TENANT/${KV_IDENTITY_TENANT}/g" ./SecretProviderClass.yaml
kubectl apply -f ./SecretProviderClass.yaml

# Deploy your application
kubectl apply -f ./deployment.yaml