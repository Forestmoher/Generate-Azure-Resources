#!/bin/bash
# Set the -e option to exit on any error
set -e

#load env vars from .env
source .env

#format variables to fit naming conventions
region_formatted=$(echo $REGION | tr '[:upper:]' '[:lower:]' | tr -d ' ')
project_name_formatted=$(echo $PROJECT_NAME | tr '[:upper:]' '[:lower:]' | tr -d ' ')

# set azure subscription
az account set --subscription $AZURE_SUBSCRIPTION_ID

# create resources:
## resource group
echo "Creating Resource Group....."
rg_name=$(\
    az group create \
    --name rg-$project_name_formatted-test-$region_formatted \
    --location $region_formatted \
    --subscription $AZURE_SUBSCRIPTION_ID \
    --output tsv \
    --query 'name')
echo "Created Resource Group: $rg_name"

## storage account
echo "Creating Storage Account....."
st_name=$(\
    az storage account create \
    --name st${project_name_formatt// /}test${region_formatted// /}001 \
    --resource-group $rg_name \
    --location $region_formatted \
    --sku Standard_LRS \
    --output tsv \
    --query 'name')
echo "Created Storage Account: $st_name"

## function app
echo "Creating Function App....."
func_name=$(\
    az functionapp create \
    --name func-$project_name_formatted-test-$region_formatted \
    --resource-group $rg_name \
    --storage-account $st_name \
    --consumption-plan-location $region_formatted \
    --os-type $FUNCTION_OS \
    --runtime $FUNCTION_RUNTIME \
    --functions-version 3 \
    --output tsv \
    --query 'name')
echo "Created Function App: $func_name"

## connect storage account to function app
echo "Connecting storage account: $st_name to function: $func_name....."
conn_str=$(\
    az storage account show-connection-string \
    --name $st_name \
    --resource-group $rg_name \
    --query connectionString \
    --output tsv)
az functionapp config appsettings set \
    --name $func_name \
    --resource-group $rg_name \
    --settings StorageConStr=$conn_str
echo "Connected storage account: $st_name to function: $func_name"

## sql server
### generate password and log to user
echo "Generating Admin Password....."
admin_password=$(node -e "console.log(require('uuid').v4())")
echo "Generated Admin Password: $admin_password Copy password, as it will not be saved and cannot be recovered" 

### create server
echo "Creating SQL Server....."
sqls_name=$(\
    az sql server create \
    --name sqls-$project_name_formatted-test-$region_formatted \
    --resource-group $rg_name \
    --location $region_formatted \
    --admin-user sqls-$project_name_formatted-test-$region_formatted-admin \
    --admin-password $admin_password \
    --enable-public-network true \
    --output tsv \
    --query 'name')
echo "Created SQL Server: $sqls_name"

### add current ip to server firewall rules
echo "Adding IP to $sqls_name firewall rules"
ip_address=$(ipconfig | grep "IPv4 Address" | awk '{print $NF}')
az sql server firewall-rule create \
    --resource-group $rg_name \
    --server $sqls_name \
    --name local \
    --start-ip-address $ip_address \
    --end-ip-address $ip_address
echo "Added IP: $ip_address to $sqls_name firewall rules"

### allow azure resources and services to access server
echo "Adding rule to allow Azure Services to access server....."
az sql server firewall-rule create \
    --resource-group $rg_name \
    --server $sqls_name \
    --name Azure Services \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0
echo "Added rule to allow Azure Services to access server"

## sql dB
echo "Creating SQL Database....."
sqldb_name=$(\
    az sql db create \
    --name sqldb-$project_name_formatted-test-$region_formatted \
    --resource-group $rg_name \
    --server $sqls_name \
    --service-objective Basic \
    --max-size 500MB \
    --backup-storage-redundancy Local \
    --output tsv \
    --query 'name')
echo "Created SQL Database: $sql_name"

## shadow dB
echo "Creating SQL Shadow Database....."
sqldb_shadow_name=$(\
    az sql db create \
    --name sqldb-$project_name_formatted-test-$region_formatted-shadow \
    --resource-group $rg_name \
    --server $sqls_name \
    --service-objective Basic \
    --max-size 500MB \
    --backup-storage-redundancy Local \
    --output tsv \
    --query 'name')
echo "Created SQL Database: $sqldb_shadow_name"

echo "Job Finished"

