RESULT=` az container show --resource-group myResourceGroup   --name appcontainer --query provisioningState --output tsv`
if [ $RESULT == "Succeeded" ]
  then
    echo "bJH5$Rth=Ht35%ZC"
  else
    echo "Please check all the issue related with this aci deployment and again execute az container create --resource-group $RESOURCEGROUP   --file /tmp/aci.yaml"
fi
