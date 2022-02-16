#!/bin/bash

# Variables
red='\e[1;31m%s\e[0m\n'
green='\e[1;32m%s\e[0m\n'
blue='\e[1;34m%s\e[0m\n'

# Set your Azure Subscription
SUBSCRIPTION=0a52391c-0d81-434e-90b4-d04f5c670e8a

# choice of dev|prod
ENVIRONMENT=dev
DEPLOYMENT_NAME=deployAPIM
PARAM_FILE="./${DEPLOYMENT_NAME}.parameters.${ENVIRONMENT}.json"
APP_NAME=$(cat $PARAM_FILE | jq -r .parameters.appName.value)
RG_NAME="rg-${APP_NAME}-${ENVIRONMENT}"
LOCATION=$(cat $PARAM_FILE | jq -r .parameters.region.value)


# Code - do not change anything here on deployment
# 1. Set the right subscription
printf "$blue" "*** Setting the subsription to $SUBSCRIPTION ***"
az account set --subscription "$SUBSCRIPTION"

# 2. Create main Resource group if not exists
az group create --name $RG_NAME --location $LOCATION
printf "$green" "*** Resource Group $RG_NAME created (or Existed) ***"


# 4. start the BICEP deployment
printf "$blue" "starting BICEP deployment for ENV: $ENVIRONMENT"
az deployment group create \
    -f ./$DEPLOYMENT_NAME.bicep \
    -g $RG_NAME \
    -p $PARAM_FILE

printf "$green" "*** Deployment finished for ENV: $ENVIRONMENT.  ***"
printf "$green" "***************************************************"

# get the outputs of the deployment
outputs=$(az deployment group show --name $DEPLOYMENT_NAME -g $RG_NAME --query properties.outputs)

# store them in variables
vnetName=$(jq -r .vnetName.value <<<$outputs)

printf "$green" "Vnet Name:       $vnetName"
