# image is sufuf3/kvgo:latest

FROM golang:latest
WORKDIR /go/kvSecrets
RUN go mod init kvSecrets
RUN go mod tidy
RUN go get -u github.com/Azure/azure-sdk-for-go/sdk/keyvault/azsecrets
RUN go get -u github.com/Azure/azure-sdk-for-go/sdk/azidentity
COPY main.go main.go