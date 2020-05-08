#!/bin/bash

## Script to convert the base lab scripts to binaries

SHC_STATUS=$(which shc > /dev/null; echo $?)
if [ $SHC_STATUS -ne 0 ]
then
    echo -e "\nError: missing shc binary...\n"
    exit 4
fi

SCRIPT_FILES="$(ls ./aci-l200lab_scripts/)"
if [ -z "$SCRIPT_FILES" ]
then
    echo -e "Error: missing aci-l200lab scripts...\n"
    exit 5
fi

function convert_to_binary() {
    SCRIPT_NAME="$1"
    BINARY_NAME="$(echo "$SCRIPT_NAME" | sed 's/.sh//')"
    shc -f ./aci-l200lab_scripts/${SCRIPT_NAME} -r -o ./aci-l200lab_binaries/${BINARY_NAME}
    rm -f ./aci-l200lab_scripts/${SCRIPT_NAME}.x.c > /dev/null 2>&1
}

for FILE in $(echo "$SCRIPT_FILES")
do
    convert_to_binary $FILE
done

exit 0
