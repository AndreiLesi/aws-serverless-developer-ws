# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import os

import boto3
from botocore.exceptions import ClientError
from aws_lambda_powertools import Logger, Tracer
from exceptions import ContractStatusNotFoundException

# Initialise Environment variables
if (SERVICE_NAMESPACE := os.environ.get("SERVICE_NAMESPACE")) is None:
    raise InternalServerError("SERVICE_NAMESPACE environment variable is undefined")
if (CONTRACT_STATUS_TABLE := os.environ.get("CONTRACT_STATUS_TABLE")) is None:
    raise InternalServerError("CONTRACT_STATUS_TABLE environment variable is undefined")


# Initialise boto3 clients
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(CONTRACT_STATUS_TABLE)  # type: ignore
logger = Logger()
tracer = Tracer()

@tracer.capture_method
@logger.inject_lambda_context(log_event=True)
def lambda_handler(event, context):
    """Function checks for the existence of a contract status entry for a specified property.

    If an entry exists, pause the workflow, and update the record with task token.

    Parameters
    ----------
    event: dict, required
        Event passed into function

    context: object
        Lambda Context runtime methods and attributes

        Context doc: https://docs.aws.amazon.com/lambda/latest/dg/python-context-object.html

    Returns
    ------
        The same input event file
    """

    detail: dict = event['Input']

    try:
        return get_contract_status(detail["property_id"])

    except ContractStatusNotFoundException:
        logger.error("Property %s does not exist. Aborting approval process.", detail["property_id"])
        raise

@tracer.capture_method
@logger.inject_lambda_context(log_event=True)
def get_contract_status(property_id: str) -> dict:
    """Returns contract status for a specified property

    Parameters
    ----------
    property_id : str
        Property ID

    Returns
    -------
    dict
        Contract info
    """

    try:
        response = table.get_item(
            Key={
                'property_id': property_id
            }
        )
        return response["Item"]

    except ClientError as error:
        if error.response["Error"]["Code"] == "ResourceNotFoundException":
            logger.error("Error getting contract.")
            raise ContractStatusNotFoundException() from error
        raise error
    except KeyError as _:
        raise ContractStatusNotFoundException() from _
