#!/bin/bash

# script name: aci-l200lab.sh
# Version v0.1.4 20200707
# Set of tools to deploy L200 Azure containers labs

# "-g|--resource-group" resource group name
# "-l|--lab" Lab scenario to deploy
# "-v|--validate" Validate a particular scenario
# "-r|--region" region to deploy the resources
# "-h|--help" help info
# "--version" print version

# read the options
TEMP=$(getopt -o g:l:r:hv --long resource-group:,lab:,region:,help,validate,version -n 'aci-l200lab.sh' -- "$@")
eval set -- "$TEMP"

# set an initial value for the flags
RESOURCE_GROUP=""
ACI_NAME="appcontainerlab"
LAB_SCENARIO=""
LOCATION="eastus2"
VALIDATE=0
HELP=0
VERSION=0

while true ;
do
    case "$1" in
        -h|--help) HELP=1; shift;;
        -g|--resource-group) case "$2" in
            "") shift 2;;
            *) RESOURCE_GROUP="$2"; shift 2;;
            esac;;
        -n|--name) case "$2" in
            "") shift 2;;
            *) ACI_NAME="$2"; shift 2;;
            esac;;
        -l|--lab) case "$2" in
            "") shift 2;;
            *) LAB_SCENARIO="$2"; shift 2;;
            esac;;
        -r|--region) case "$2" in
            "") shift 2;;
            *) LOCATION="$2"; shift 2;;
            esac;;    
        -v|--validate) VALIDATE=1; shift;;
        --version) VERSION=1; shift;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

# Variable definition
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_NAME="$(echo $0 | sed 's|\.\/||g')"
SCRIPT_VERSION="Version v0.1.4 20200707"

# Funtion definition

# az login check
function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\nError: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}

# check resource group and cluster
function check_resourcegroup_aci () {
    RG_EXIST=$(az group show -g $RESOURCE_GROUP &>/dev/null; echo $?)
    if [ $RG_EXIST -ne 0 ]
    then
        echo -e "\nCreating resource group ${RESOURCE_GROUP}...\n"
        az group create --name $RESOURCE_GROUP --location $LOCATION &>/dev/null
    else
        echo -e "\nResource group $RESOURCE_GROUP already exists...\n"
    fi

    ACI_EXIST=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)
    if [ $ACI_EXIST -eq 0 ]
    then
        echo -e "\nContainer instance $ACI_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 4
    fi
}

# validate ACI exists
function validate_aci_exists () {
    ACI_EXIST=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)
    if [ $ACI_EXIST -ne 0 ]
    then
        echo -e "\nERROR: Container instance $ACI_NAME does not exists in resource group ${RESOURCE_GROUP}...\n"
        exit 5
    fi
}

# Lab scenario 1
function lab_scenario_1 () {
    echo -e "Deploying scenario for lab1...\n"
    az container create \
    --name $ACI_NAME \
    --resource-group $RESOURCE_GROUP \
    --image mcr.microsoft.com/azuredocs/aci-helloworld \
    --vnet aci-vnet-lab200aci \
    --vnet-address-prefix 10.0.0.0/16 \
    --subnet aci-subnet-lab200aci \
    --subnet-address-prefix 10.0.0.0/24 \
    -o table

    validate_aci_exists
    
    NETWORKPROFILE=$(az network profile list --resource-group $RESOURCE_GROUP --query [0].id --output tsv)

cat <<EOF > aci.yaml
apiVersion: '2018-10-01'
location: eastus2
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

    ERROR_MESSAGE="$(az container create --resource-group $RESOURCE_GROUP --file aci.yaml 2>&1)"
    
    echo -e "\n\n********************************************************"
    echo -e "Customer has an ACI alredy deployed in the resourece group $RESOURCE_GROUP and he wants to deploy another one in the same resource group using the following:"
    echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
    echo -e "He is getting the error message:\n $ERROR_MESSAGE \n"
    echo -e "The yaml file aci.yaml is in your current path, you have to modified it in order to be able to deploy the second container instance \"appcontaineryaml\"\n"
    echo -e "Once you find the issue, update the aci.yaml file and run the commnad:"
    echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
}

function lab_scenario_1_validation () {
    echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "Running validation for Lab scenario $LAB_SCENARIO\n"
    validate_aci_exists
    ACI_STATUS=$(az container show -g $RESOURCE_GROUP -n appcontaineryaml &>/dev/null; echo $?)
    if [ $ACI_STATUS -eq 0 ]
    then
        echo -e "\n\n========================================================"
        echo -e '\nContainer instance "appcontaineryaml" looks good now, the keyword for the assesment is:\n\nbJH5$Rth=Ht35%ZC\n'
    else
        echo -e "\nScenario $LAB_SCENARIO is still FAILED\n\n"
        echo -e "The yaml file aci.yaml is in your current path, you have to modified it in order to be able to deploy the second container instance \"appcontaineryaml\"\n"
        echo -e "Once you find the issue, update the aci.yaml file and run the commnad:"
        echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
    fi
}

# Lab scenario 2
function lab_scenario_2 () {
    echo -e "Deploying scenario for lab2...\n"
    az container create \
    --name $ACI_NAME \
    --resource-group $RESOURCE_GROUP \
    --image alpine \
    --ports 80 \
    -o table

    validate_aci_exists
    ACI_URI=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query id -o tsv 2>/dev/null)
    
    echo -e "\n\n********************************************************"
    echo -e "An ACI has been deployed with name $ACI_NAME in the resourece group $RESOURCE_GROUP, and it keeps restarting."
    echo -e "Looks like it was deployed with the wrong image."
    echo -e "You have to update the ACI to change the image to nginx.\n"
    echo -e "ACI URI=${ACI_URI}\n"
}

function lab_scenario_2_validation () {
    echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "Running validation for Lab scenario $LAB_SCENARIO\n"
    validate_aci_exists
    ACI_IMAGE="$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query containers[].image -o tsv)"
    RESTART_COUNT="$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query containers[].instanceView.restartCount -o tsv)"
    ACI_STATUS=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)
    if [ $ACI_STATUS -eq 0 ] && [[ "$ACI_IMAGE" == "nginx" || "$ACI_IMAGE" == "nginx:alpine" ]] && [ $RESTART_COUNT -eq 0 ]
    then
        echo -e "\n\n========================================================"
        echo -e "\nContainer instance \"${ACI_NAME}\" looks good now, the keyword for the assesment is:\n\njpDajuBxs69Ky28z\n"
    else
        echo -e "\nScenario $LAB_SCENARIO is still FAILED\n\n"
    fi
}

# Lab scenario 3
function lab_scenario_3 () {
    echo -e "Deploying scenario for lab3...\n"
    az container create \
    --name $ACI_NAME \
    --resource-group $RESOURCE_GROUP \
    --image sturrent/acilab3:latest \
    -o table

    validate_aci_exists
    ACI_URI=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query id -o tsv 2>/dev/null)
    
    echo -e "\n\n********************************************************"
    echo -e "An ACI has been deployed with name $ACI_NAME in the resourece group $RESOURCE_GROUP."
    echo -e "The logs of this container instance have some interensting infromation."
    echo -e "ACI URI=${ACI_URI}\n"
}

function lab_scenario_3_validation () {
    echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "Running validation for Lab scenario $LAB_SCENARIO\n"
    validate_aci_exists
    echo -e "\n\n========================================================"
    echo -e "\You will get what you are looking for from the container application logs...\n"
}

#if -h | --help option is selected usage will be displayed
if [ $HELP -eq 1 ]
then
	echo "aci-l200lab usage: aci-l200lab -g <RESOURCE_GROUP> -l <LAB#> [-v|--validate] [-r|--region] [-h|--help] [--version]"
    echo -e "\nHere is the list of current labs available:\n
***************************************************************
*\t 1. ACI deployment on existing resource group fails
*\t 2. ACI deployed with wrong image
*\t 3. ACI checking container logs
***************************************************************\n"
    echo -e '"-g|--resource-group" resource group name
"-l|--lab" Lab scenario to deploy
"-r|--region" region to create the resources
"-v|--validate" Validate a particular scenario
"--version" print version of aci-l200lab
"-h|--help" help info\n'
	exit 0
fi

if [ $VERSION -eq 1 ]
then
	echo -e "$SCRIPT_VERSION\n"
	exit 0
fi

if [ -z $RESOURCE_GROUP ]; then
	echo -e "Error: Resource group value must be provided. \n"
	echo -e "aci-l200lab usage: aci-l200lab -g <RESOURCE_GROUP> -l <LAB#> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
	exit 7
fi

if [ -z $LAB_SCENARIO ]; then
	echo -e "Error: Lab scenario value must be provided. \n"
	echo -e "aci-l200lab usage: aci-l200lab -g <RESOURCE_GROUP> -l <LAB#> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
    echo -e "\nHere is the list of current labs available:\n
***************************************************************
*\t 1. ACI deployment on existing resource group fails
*\t 2. ACI deployed with wrong image
*\t 3. 
***************************************************************\n"
	exit 9
fi

# lab scenario has a valid option
if [[ ! $LAB_SCENARIO =~ ^[1-3]+$ ]];
#if [[ ! $LAB_SCENARIO -eq 1 ]];
then
    echo -e "\nError: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value from 1 to 3\n"
    #echo -e "\nError: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value of 1\n"
    exit 10
fi

# main
echo -e "\nWelcome to the ACI Troubleshooting sessions
***********************************************

This tool will use your internal azure account to deploy the lab environment.
Verifing if you are authenticated already...\n"

# Verify az cli has been authenticated
az_login_check

if [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_aci
    lab_scenario_1

elif [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_1_validation
    
elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_aci
    lab_scenario_2

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_2_validation

elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_aci
    lab_scenario_3

elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_3_validation

else
    echo -e "\nError: no valid option provided\n"
    exit 11
fi

exit 0