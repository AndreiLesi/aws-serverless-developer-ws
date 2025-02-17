#!/usr/bin/env bash
echo "RUN ME FROM THE ROOT OF THE REPO!"
cd terraform
DDB_TBL_NAME="$(terraform state show module.unicorn_web.aws_dynamodb_table.properties | grep "name" | grep "Serverless*" | awk -F" = " '{print $2}'| tr -d '"')"
echo "DDB_TABLE_NAME: '${DDB_TBL_NAME}'"

echo "LOADING ITEMS TO DYNAMODB:"
cd ../tests/data
aws ddb put ${DDB_TBL_NAME} file://property_data.json
echo "DONE!"
cd ../../