# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import os
from datetime import datetime
from schema.contractstatuschanged import (
AWSEvent, ContractStatusChanged, Marshaller)
import boto3
from aws_lambda_powertools import Logger, Tracer

# Initialise Environment variables
if (SERVICE_NAMESPACE := os.environ.get("SERVICE_NAMESPACE")) is None:
    raise InternalServerError("SERVICE_NAMESPACE environment variable is undefined")
if (CONTRACT_STATUS_TABLE := os.environ.get("CONTRACT_STATUS_TABLE")) is None:
    raise InternalServerError("CONTRACT_STATUS_TABLE environment variable is undefined")
logger = Logger()
tracer = Tracer()

# Initialise boto3 clients
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(CONTRACT_STATUS_TABLE)  # type: ignore

# Get current date
now = datetime.now()
current_date = now.strftime("%d/%m/%Y %H:%M:%S")

@tracer.capture_method
def lambda_handler(event, context):
    """Event handler for ContractStatusChangedEvent

    Parameters
    ----------
    event: dict, required
        EventBridge Events Format

    context: object, required
        Lambda Context runtime methods and attributes

        Context doc: https://docs.aws.amazon.com/lambda/latest/dg/python-context-object.html

    Returns
    ------
        The same input event file
    """
    # Deserialize event into strongly typed object
    awsEvent:AWSEvent = Marshaller.unmarshall(event, AWSEvent)
    detail:ContractStatusChanged = awsEvent.detail
    save_contract_status(detail, context)

    # return OK, async function
    return {
        "statusCode": 200,
    }

@tracer.capture_method
@logger.inject_lambda_context(log_event=True)
def save_contract_status(contract_status_changed_event, context):
    """Saves contract status in contract status table

    Args:
        contract_status_changed_event (dict):
            Contract_status_changed_event

    Returns:
        dict: _description_
    """
    logger.info("Saving contract status to contract status table. %s", contract_status_changed_event.contract_id)

    return table.update_item(
                    Key={
                        'property_id': contract_status_changed_event.property_id
                    },
                    UpdateExpression="set contract_status=:t, contract_last_modified_on=:m, contract_id=:c",
                    ExpressionAttributeValues={
                        ':c': contract_status_changed_event.contract_id,
                        ':t': contract_status_changed_event.contract_status,
                        ':m': contract_status_changed_event.contract_last_modified_on
                    }
            )
