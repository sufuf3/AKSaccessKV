// go run main.go
// https://learn.microsoft.com/en-us/azure/key-vault/secrets/quick-create-go#sample-code

package main

import (
    "context"
    "os"
    "fmt"
    "log"

    "github.com/Azure/azure-sdk-for-go/sdk/azidentity"
    "github.com/Azure/azure-sdk-for-go/sdk/keyvault/azsecrets"
)

func main() {
    mySecretName := os.Getenv("SECRET_NAME")
    vaultURI := os.Getenv("KEYVAULT_URL")

    // Create a credential using the NewDefaultAzureCredential type.
    cred, err := azidentity.NewDefaultAzureCredential(nil)
    if err != nil {
        log.Fatalf("failed to obtain a credential: %v", err)
    }

    // Establish a connection to the Key Vault client
    client, err := azsecrets.NewClient(vaultURI, cred, nil)

    // Get a secret. An empty string version gets the latest version of the secret.
    version := ""
    resp, err := client.GetSecret(context.TODO(), mySecretName, version, nil)
    if err != nil {
        log.Fatalf("failed to get the secret: %v", err)
    }
    fmt.Printf("secretName: %s\n", os.Getenv("SECRET_NAME"))
    fmt.Printf("secretValue: %s\n", *resp.Value)
}