# Workload Identity for Secret Store CSI driver

## Setup

### Prerequisites
- Create or use an existing Azure Key Vault
- AKS cluster should --enable-addons azure-keyvault-secrets-provider --enable-oidc-issuer --enable-workload-identity
###Steps
1. Create a managed identity
2. grants the workload identity permission to access the key vault secrets
  - Check Key Vault's Access configuration
  <img width="274" alt="image" src="https://github.com/sufuf3/AKSaccessKV/assets/8349587/66428134-9f03-4f70-962d-2fce2a6791e2">
  - If Key Vault’s data plane access by using an Azure RBAC
    ```
    az role assignment create --role "Key Vault Administrator" --assignee $USER_ASSIGNED_CLIENT_ID --scope $KEYVAULT_SCOPE
    ```
  - If Key Vault’s data plane access by using a Key Vault access policy
    ```
    az keyvault set-policy --name "${KEYVAULT_NAME}" --secret-permissions get --spn "${USER_ASSIGNED_CLIENT_ID}"
    ```
3. Create a ServiceAccount K8s resource with the managed identity’s ClientID
```
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
```
4. Create the federated identity credential between the managed identity, service account issuer, and subject
```
az identity federated-credential create --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${AKS_OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange
```
5. Deploy a SecretProviderClass
```
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kvname-wi # needs to be unique per namespace
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    clientID: "${USER_ASSIGNED_CLIENT_ID}" # Setting this to use workload identity
    keyvaultName: ${KEYVAULT_NAME}         # Set to the name of your key vault
    cloudName: ""                          # [OPTIONAL for Azure] defaults is AzurePublicCloud
    objects:  |
      array:
        - |
          objectName: secret1              # Set to the name of your secret
          objectType: secret               # object types: secret, key, or cert
          objectVersion: ""                # [OPTIONAL] object versions, default to latest if empty
    tenantId: "${IDENTITY_TENANT}"         # The tenant ID of the key vault
```
6. Deploy a workload
```
kind: Pod
apiVersion: v1
metadata:
  name: busybox-secrets-store-inline-wi
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: "workload-identity-sa"
  containers:
    - name: busybox
      image: registry.k8s.io/e2e-test-images/busybox:1.29-4
      command: ["/bin/tail"]
      args: ["-f", "/etc/passwd"]
      volumeMounts:
      - name: secrets-store01-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
  volumes:
    - name: secrets-store01-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kvname-wi"
```
## Verification

```
kubectl describe po busybox-secrets-store-inline-wi-5dd99c6b4c-6zpdt
Name:             busybox-secrets-store-inline-wi-5dd99c6b4c-6zpdt
Namespace:        default
Priority:         0
Service Account:  csi-wi-sa
Node:             aks-nodepool2-88456364-vmss000008/10.224.0.4
Start Time:       Thu, 30 May 2024 14:40:50 +0800
Labels:           app=secrets-wi
                  azure.workload.identity/use=true
                  pod-template-hash=5dd99c6b4c
Annotations:      <none>
Status:           Running
IP:               10.244.4.13
IPs:
  IP:           10.244.4.13
Controlled By:  ReplicaSet/busybox-secrets-store-inline-wi-5dd99c6b4c
Containers:
  secrets-wi:
    Container ID:  containerd://b1eb604bae260e172fc70e92f73b7b7570b6a21e22f2c0368ee8e7cc7f3ebb1d
    Image:         registry.k8s.io/e2e-test-images/busybox:1.29-4
    Image ID:      registry.k8s.io/e2e-test-images/busybox@sha256:2e0f836850e09b8b7cc937681d6194537a09fbd5f6b9e08f4d646a85128e8937
    Port:          <none>
    Host Port:     <none>
    Command:
      /bin/tail
    Args:
      -f
      /etc/passwd
    State:          Running
      Started:      Thu, 30 May 2024 14:41:56 +0800
    Ready:          True
    Restart Count:  0
    Environment:
      AZURE_CLIENT_ID:             8eeec9f6-xxxx-xxxx-xxxx-dc86c47b50cf
      AZURE_TENANT_ID:             72f988bf-xxxx-xxxx-xxxx-2d7cd011db47
      AZURE_FEDERATED_TOKEN_FILE:  /var/run/secrets/azure/tokens/azure-identity-token
      AZURE_AUTHORITY_HOST:        https://login.microsoftonline.com/
    Mounts:
      /mnt/secrets-store from secrets-store01-inline (ro)
      /var/run/secrets/azure/tokens from azure-identity-token (ro)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-kdq85 (ro)
```
