# Reference: https://learn.microsoft.com/en-us/python/api/overview/azure/keyvault-secrets-readme?view=azure-python#retrieve-a-secret

import os
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()

secret_client = SecretClient(vault_url=os.environ.get('KEYVAULT_URL'), credential=credential)
secret = secret_client.get_secret(os.environ.get('SECRET_NAME'))

print("Secret Name: " + secret.name)
print("Secret Value: " + secret.value)