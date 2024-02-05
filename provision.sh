#!/bin/bash
export RESOURCE_GROUP="kvrg"
export LOCATION="eastus"
export SERVICE_ACCOUNT_NAMESPACE="default"
export SERVICE_ACCOUNT_NAME="workload-identity-sa"
export SUBSCRIPTION="$(az account show --query id --output tsv)"
export USER_ASSIGNED_IDENTITY_NAME="sjUAIdentity"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="sjFIdentity"
export AKS_NAME="kvaks"

# Create AKS cluster
az group create -l "${LOCATION}" -n "${RESOURCE_GROUP}"
az aks create -g "${RESOURCE_GROUP}" -n "${AKS_NAME}" --addons azure-keyvault-secrets-provider --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys --node-vm-size Standard_B2s --node-count 1

# Retrieve the OIDC Issuer URL
export AKS_OIDC_ISSUER="$(az aks show -n "${AKS_NAME}" -g "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" -o tsv)"
echo $AKS_OIDC_ISSUER

# Create an Azure Key Vault and secret
export KEYVAULT_NAME="sjkvtw"
export KEYVAULT_SECRET_NAME="mysecret"

az keyvault create --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --name "${KEYVAULT_NAME}" --enable-rbac-authorization false
az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name "${KEYVAULT_SECRET_NAME}" --value 'Hello!'
