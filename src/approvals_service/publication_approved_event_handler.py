# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
from typing import Tuple
import os
import re
from schema.unicorn_properties.publicationevaluationcompleted import (PublicationEvaluationCompleted, Marshaller, AWSEvent)
from aws_lambda_powertools.logging import Logger
from aws_lambda_powertools.tracing import Tracer
import boto3


# Initialise Environment variables
if (SERVICE_NAMESPACE := os.environ.get('SERVICE_NAMESPACE')) is None:
    raise EnvironmentError('SERVICE_NAMESPACE environment variable is undefined')
if (DYNAMODB_TABLE := os.environ.get('DYNAMODB_TABLE')) is None:
    raise EnvironmentError('DYNAMODB_TABLE environment variable is undefined')

logger = Logger(service=SERVICE_NAMESPACE)
tracer = Tracer(service=SERVICE_NAMESPACE)

EXPRESSION = r"[a-z-]+\/[a-z-]+\/[a-z][a-z0-9-]*\/[0-9-]+"
TARGET_STATE = 'PENDING'

# Initialise boto3 clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)  # type: ignore

@tracer.capture_method
def get_keys_for_property(property_id: str) -> Tuple[str, str]:
    # Validate Property ID
    if not re.fullmatch(EXPRESSION, property_id):
        error_msg = f"Invalid property id '{property_id}'; must conform to regular expression: {EXPRESSION}"
        logger.error(error_msg)
        return '', ''

    # Extract components from property_id
    country, city, street, number = property_id.split('/')

    # Construct DDB PK & SK keys for this property
    pk_details = f"{country}#{city}".replace(' ', '-').lower()
    pk = f"PROPERTY#{pk_details}"
    sk = f"{street}#{str(number)}".replace(' ', '-').lower()
    return pk, sk

@tracer.capture_method
def publication_approved(event_detail, errors):
    """Add new property to database; responds to HTTP POST with JSON payload; generates DynamoDB structure

    Parameters
    ----------
    event_detail
    errors : Element containing any errors from the approval workflow - default: None

    Returns
    -------
    Success message upon successful storage of the approval outcome into DynamoDB
    """
    logger.info(event_detail)

    property_id = event_detail.property_id
    evaluation_result = event_detail.evaluation_result
    country, city, street, number = property_id.split('/')

    pk_details = f"{country}#{city}".replace(' ', '-').lower()
    pk = f"PROPERTY#{pk_details}"
    sk = f"{street}#{str(number)}".replace(' ', '-').lower()

    logger.info(f"Storing new property in DynamoDB with PK {pk} and SK {sk}")
    dynamodb_response = table.update_item(
        Key={
            'PK': pk,
            'SK': sk,
        },
        AttributeUpdates={
            'status': {
                'Value': evaluation_result,
                'Action': 'PUT',
            }
        },
    )
    http_status_code = dynamodb_response['ResponseMetadata']['HTTPStatusCode']
    logger.info(f"Stored item in DynamoDB; responded with status code {http_status_code}")

    return { 'result': 'Successfully updated property status' }

@tracer.capture_lambda_handler
@logger.inject_lambda_context
def lambda_handler(event, context):
    """Main entry point for Property Approval lambda function

    Parameters
    ----------
    event : EventBridge event payload
        The event passed to the function.
    context : AWS Lambda Context
        The context for the Lambda function.

    Returns
    -------
    Success message upon successful storage of the approval outcome into DynamoDB
    """

    logger.info(event)

    errors = None if 'workflowErrors' not in event['detail'] else event['detail'].pop('workflowErrors')

    # Deserialize event into strongly typed object
    aws_event = Marshaller.unmarshall(event, AWSEvent)
    detail:PublicationEvaluationCompleted = aws_event.detail

    return publication_approved(detail, errors)
