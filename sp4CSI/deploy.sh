#!/bin/bash
export RESOURCE_GROUP="kvrg"
export LOCATION="eastus"
export SERVICE_ACCOUNT_NAMESPACE="default"
export SERVICE_ACCOUNT_NAME="csi-wi-sa"
export SUBSCRIPTION="$(az account show --query id --output tsv)"
export UAMI="sjUAMI4csi"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="sjFI4csi"
export CLUSTER_NAME="kvaks"
export KEYVAULT_NAME="sjkvtw"

export SPNAME="sjsp4csitest"
az ad sp create-for-rbac --skip-assignment --name $SPNAME
#{
#  "appId": "f86cf965-268c-48f7-9a6e-462899f3bef3",
#  "displayName": "sjsp4csitest",
#  "password": "PAj8Q~xxxxx_jCiNsdEk4tnf1wUle82FHqcXl",
#  "tenant": "72f988bf-86f1-41af-91ab-2d7cd011db47"
#}

export AZURE_CLIENT_ID=$(az ad sp list --display-name ${SPNAME} --query [0].appId -o tsv)
export KEYVAULT_RESOURCE_GROUP="kvrg"

az keyvault set-policy -n $KEYVAULT_NAME --key-permissions get --spn $AZURE_CLIENT_ID
az keyvault set-policy -n $KEYVAULT_NAME --secret-permissions get --spn $AZURE_CLIENT_ID
az keyvault set-policy -n $KEYVAULT_NAME --certificate-permissions get --spn $AZURE_CLIENT_ID

echo "enter SP password: "
read PASSWORD
kubectl create secret generic secrets-store-creds --from-literal clientid=$AZURE_CLIENT_ID --from-literal clientsecret=$PASSWORD
kubectl label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

export KV_IDENTITY_TENANT=$(az keyvault show --name "${KEYVAULT_NAME}" --query "properties.tenantId")
sed -i -e "s/KEYVAULT_NAME/${KEYVAULT_NAME}/g" ./SecretProviderClass.yaml
sed -i -e "s/IDENTITY_TENANT/${KV_IDENTITY_TENANT}/g" ./SecretProviderClass.yaml
kubectl apply -f ./SecretProviderClass.yaml

kubectl apply -f ./deployment.yaml