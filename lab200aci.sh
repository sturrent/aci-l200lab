#!/bin/bash

# script name: l200labs.sh
# Version v0.2.1 07052020
# Set of tools to deploy L200 Azure containers labs

# az login check
function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\nError: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}

# Verify az cli has been authenticated

# main
echo -e "\nWelcome to the L200 Troubleshooting sessions
********************************************

This tool will use your internal azure account to deploy the lab environment.
Verifing if you are authenticated already...\n"

# Verify az cli has been authenticated
az_login_check

echo "Please provide the name of the resourcegroup"
read -p "Please Enter a the ResourceGroup name: `echo $'\n> '`" RESOURCEGROUP
az group create -l westus -n $RESOURCEGROUP


az container create \
  --name appcontainerlab200aci \
  --resource-group $RESOURCEGROUP \
  --image mcr.microsoft.com/azuredocs/aci-helloworld \
  --vnet aci-vnet-lab200aci \
  --vnet-address-prefix 10.0.0.0/16 \
  --subnet aci-subnet-lab200aci \
  --subnet-address-prefix 10.0.0.0/24

NETWORKPROFILE=`az network profile list --resource-group $RESOURCEGROUP   --query [0].id --output tsv`


cat <<EOF > aci.yaml
apiVersion: '2018-10-01'
location: westus
name: appcontaineryaml
properties:
  containers:
  - name: appcontaineryaml
    properties:
      image: mcr.microsoft.com/azuredocs/aci-helloworld
      ports:
      - port: 80
        protocol: TCP
      resources:
        requests:
          cpu: 1.0
          memoryInGB: 1.5
  ipAddress:
    type: Public
    ports:
    - protocol: tcp
      port: '80'
  networkProfile:
    id: $NETWORKPROFILE
  osType: Linux
  restartPolicy: Always
tags: null
type: Microsoft.ContainerInstance/containerGroups
EOF
az container create --resource-group $RESOURCEGROUP   --file /tmp/aci.yaml
RESULT=`az container show --resource-group $RESOURCEGROUP   --name appcontaineryaml --query provisioningState --output tsv`
if [ $RESULT == "Succeeded" ]
  then
    echo "Lab is not properly configured"
  else
    echo "Please check all the issue related with this aci deployment and again execute az container create --resource-group $RESOURCEGROUP   --file /tmp/aci.yaml"
fi

echo "Once the issue is fixed, please run the lab test results by executing  sh test_results.sh"
