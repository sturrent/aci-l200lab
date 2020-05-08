#!/bin/bash

# script name: l200labs.sh
# Version v0.2.25 20191224
# Set of tools to deploy L200 Azure containers labs

# "-g|--resource-group" resource group name
# "-n|--name" AKS cluster name
# "-l|--lab" Lab scenario to deploy (5 possible options)
# "-v|--validate" Validate a particular scenario
# "-r|--region" region to deploy the resources
# "-h|--help" help info
# "--version" print version

# read the options
TEMP=`getopt -o g:n:l:r:hv --long resource-group:,name:,lab:,region:,help,validate,version -n 'l200labs.sh' -- "$@"`
eval set -- "$TEMP"

# set an initial value for the flags
RESOURCE_GROUP=""
CLUSTER_NAME=""
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
            *) CLUSTER_NAME="$2"; shift 2;;
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
SCRIPT_VERSION="Version v0.2.25 20191224"

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
function check_resourcegroup_cluster () {
    RG_EXIST=$(az group show -g $RESOURCE_GROUP &>/dev/null; echo $?)
    if [ $RG_EXIST -ne 0 ]
    then
        echo -e "\nCreating resource group ${RESOURCE_GROUP}...\n"
        az group create --name $RESOURCE_GROUP --location $LOCATION &>/dev/null
    else
        echo -e "\nResource group $RESOURCE_GROUP already exists...\n"
    fi

    CLUSTER_EXIST=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null; echo $?)
    if [ $CLUSTER_EXIST -eq 0 ]
    then
        echo -e "\nCluster $CLUSTER_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 4
    fi
}

# validate cluster exists
function validate_cluster_exists () {
    CLUSTER_EXIST=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null; echo $?)
    if [ $CLUSTER_EXIST -ne 0 ]
    then
        echo -e "\nERROR: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP does not exists...\n"
        exit 5
    fi
}

# Lab scenario 1
function lab_scenario_1 () {
    echo -e "Deploying cluster for lab1...\n"
    az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --vm-set-type AvailabilitySet \
    --node-count 3 \
    --generate-ssh-keys \
    --tag l200lab=${LAB_SCENARIO} \
    -o table

    validate_cluster_exists

    echo -e "Getting kubectl credentials for the cluster...\n"
    az aks get-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME"
    
    NODE_RESOURCE_GROUP="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query nodeResourceGroup -o tsv)"
    VM_NODE_0="$(az vm list -g $NODE_RESOURCE_GROUP --query [0].name -o tsv)"
    echo -e "\n\nPlease wait while we are preparing the environment for you to troubleshoot..."
    az vm run-command invoke \
    -g $NODE_RESOURCE_GROUP \
    -n $VM_NODE_0 \
    --command-id RunShellScript --scripts "sudo systemctl stop kubelet; sudo systemctl disable kubelet; sudo systemctl stop docker" &> /dev/null
    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"
    echo -e "Please Log in to the corresponding node and check basic services like kubelet, docker etc...\n"
    echo -e "Cluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_1_validation () {
    validate_cluster_exists
    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags.l200lab -o tsv)"
    if [ -z $LAB_TAG ]
    then
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    elif [ $LAB_TAG -eq 1 ]
    then
        az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
        if $(kubectl get nodes | grep -q "NotReady")
        then
            echo -e "\nScenario $LAB_SCENARIO is still FAILED\n"
        else
            echo -e "\nCluster looks good now, the keyword for the assesment is:\n\nhometradebroke\n"
        fi
    else
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    fi
}

# Lab scenario 2
function lab_scenario_2 () {
    az network vnet create --name customvnetlab2 \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --address-prefixes 20.0.0.0/26 \
    --subnet-name customsubnetlab2 \
    --subnet-prefixes 20.0.0.0/26 &>/dev/null
    SUBNET_ID="$(az network vnet show -g $RESOURCE_GROUP -n customvnetlab2 --query subnets[0].id -o tsv)"
    az aks create --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --vm-set-type AvailabilitySet \
    --generate-ssh-keys \
    -c 1 -s Standard_B2ms \
    --network-plugin azure \
    --vnet-subnet-id  $SUBNET_ID \
    --tag l200lab=${LAB_SCENARIO} \
    -o table

    validate_cluster_exists
    az aks scale -g $RESOURCE_GROUP -n $CLUSTER_NAME -c 4 &> /dev/null
    az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"
    echo -e "\n\n********************************************************"
    echo -e "\nIt seems cluster is in failed state, please check the issue and resolve it appropriately\n"
    echo -e "Cluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_2_validation () {
    validate_cluster_exists
    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags.l200lab -o tsv)"
    if [ -z $LAB_TAG ]
    then
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    elif [ $LAB_TAG -eq $LAB_SCENARIO ]
    then
        if $(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query provisioningState -o tsv | grep -q "Succeeded")
        then
            echo -e "\nCluster looks good now, the keyword for the assesment is:\n\nstopeffortsweet\n"
        else
            echo -e "\nScenario $LAB_SCENARIO is still FAILED\n"
        fi
    else
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    fi
}

# Lab scenario 3
function lab_scenario_3 () {
    az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --vm-set-type AvailabilitySet \
    --node-count 1 \
    --generate-ssh-keys \
    --tag l200lab=${LAB_SCENARIO} \
    -o table

    validate_cluster_exists
    NODE_RESOURCE_GROUP="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query nodeResourceGroup -o tsv)"
    CLUSTER_NSG="$(az network nsg list -g $NODE_RESOURCE_GROUP --query [0].name -o tsv)"
    az network nsg rule create -g $NODE_RESOURCE_GROUP --nsg-name $CLUSTER_NSG \
    -n MyNsgRuleWithTags  --priority 400 \
    --source-address-prefixes VirtualNetwork \
    --destination-address-prefixes Internet \
    --destination-port-ranges "*" \
    --direction Outbound \
    --access Deny \
    --protocol Tcp \
    --description "Deny to Internet." &> /dev/null
    az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
    az aks scale -g $RESOURCE_GROUP -n $CLUSTER_NAME -c 2 &>/dev/null
    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"
    echo "Cluster is missing a node after scale action (\"kubectl get nodes only shows\" 1 node), please check the issue and resolve it appropriately"
    echo -e "\nCluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_3_validation () {
    validate_cluster_exists
    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags.l200lab -o tsv)"
    if [ -z $LAB_TAG ]
    then
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    elif [ $LAB_TAG -eq $LAB_SCENARIO ]
    then
        az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
        if [ "$(kubectl get no | grep ' Ready' | wc -l)" -ge 2 ]
        then
            echo -e "\nCluster looks good now, the keyword for the assesment is:\n\nnorthernjumpaway\n"
        else
            echo -e "\nScenario $LAB_SCENARIO is still FAILED\n"
        fi
    else
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    fi
}

# Lab scenario 4
function lab_scenario_4 () {
    az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --node-count 1 \
    --vm-set-type AvailabilitySet \
    --generate-ssh-keys \
    --tag l200lab=${LAB_SCENARIO} \
    -o table

    validate_cluster_exists
    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"
    echo -e "\n\nPlease try using kubernetes dashboard and try to create a pod called nginx in test namespace using the dashboard\n"
    echo -e "\nCluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_4_validation () {
    validate_cluster_exists
    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags.l200lab -o tsv)"
    if [ -z $LAB_TAG ]
    then
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    elif [ $LAB_TAG -eq $LAB_SCENARIO ]
    then
        az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
        kubectl get clusterrolebinding -n kube-system | grep -i dashboard &>/dev/null
        if [ $? -eq 0 ]
        then
            echo -e "\nYou should be able to access the $CLUSTER_NAME cluster dashboard, the keyword for the assesment is:\n\nbestkitchenplains\n"
        else
            echo -e "\nStill the dashboard issue persists\n"
        fi
    else
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    fi    
}

# Lab scenario 5
function lab_scenario_5 () {
    az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --node-count 1 \
    --vm-set-type AvailabilitySet \
    --generate-ssh-keys \
    --tag l200lab=${LAB_SCENARIO} \
    -o table

    validate_cluster_exists
    NODE_RESOURCE_GROUP="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query nodeResourceGroup -o tsv)"
    VNET_NAME="$(az network vnet list -g $NODE_RESOURCE_GROUP --query [0].name -o tsv)"
    echo -e "\nCompleting the lab setup..."
    az network vnet update -g $NODE_RESOURCE_GROUP -n $VNET_NAME --dns-servers 10.2.0.8 &>/dev/null
    VM_NODE_0="$(az vm list -g $NODE_RESOURCE_GROUP --query [0].name -o tsv)"
    az vm restart -g $NODE_RESOURCE_GROUP -n $VM_NODE_0 --no-wait
    az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"
    echo -e "\n\nThere are issues with one node in NotReady\n"
    echo -e "\nCluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_5_validation () {
    validate_cluster_exists
    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags.l200lab -o tsv)"
    if [ -z $LAB_TAG ]
    then
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    elif [ $LAB_TAG -eq $LAB_SCENARIO ]
    then
        az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
        if $(kubectl get nodes | grep -q "NotReady")
        then
            echo -e "\nScenario $LAB_SCENARIO is still FAILED\n"
        else
            echo -e "\nCluster looks good now, the keyword for the assesment is:\n\namountdevicerose\n"
        fi
    else
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 6
    fi
}

#if -h | --help option is selected usage will be displayed
if [ $HELP -eq 1 ]
then
	echo "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-r|--region] [-h|--help] [--version]"
    echo -e "\nHere is the list of current labs available:\n
***************************************************************
*\t 1. Node not ready
*\t 2. Cluster is in failed state
*\t 3. Cluster Scaling issue, missing one node
*\t 4. Problem with accessing dashboard
*\t 5. Cluster unable to communicate with API server
***************************************************************\n"
    echo -e '"-g|--resource-group" resource group name
"-n|--name" AKS cluster name
"-l|--lab" Lab scenario to deploy (5 possible options)
"-r|--region" region to create the resources
"-v|--validate" Validate a particular scenario
"--version" print version of l200labs
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
	echo -e "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
	exit 7
fi

if [ -z $CLUSTER_NAME ]; then
	echo -e "Error: Cluster name value must be provided. \n"
	echo -e "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
	exit 8
fi

if [ -z $LAB_SCENARIO ]; then
	echo -e "Error: Lab scenario value must be provided. \n"
	echo -e "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
    echo -e "\nHere is the list of current labs available:\n
***************************************************************
*\t 1. Node not ready
*\t 2. Cluster is in failed state
*\t 3. Cluster Scaling issue
*\t 4. Problem with accessing dashboard
*\t 5. Cluster unable to communicate with API server
***************************************************************\n"
	exit 9
fi

# lab scenario has a valid option
if [[ ! $LAB_SCENARIO =~ ^[1-5]+$ ]];
then
    echo -e "\nError: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value from 1 to 5\n"
    exit 10
fi

# main
echo -e "\nWelcome to the L200 Troubleshooting sessions
********************************************

This tool will use your internal azure account to deploy the lab environment.
Verifing if you are authenticated already...\n"

# Verify az cli has been authenticated
az_login_check

if [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_1

elif [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_1_validation

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_2

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_2_validation

elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_3

elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_3_validation

elif [ $LAB_SCENARIO -eq 4 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_4

elif [ $LAB_SCENARIO -eq 4 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_4_validation

elif [ $LAB_SCENARIO -eq 5 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_5

elif [ $LAB_SCENARIO -eq 5 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_5_validation

else
    echo -e "\nError: no valid option provided\n"
    exit 11
fi

exit 0
