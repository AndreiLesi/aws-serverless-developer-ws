import os
import zipfile
from urllib.request import urlopen
import boto3
from aws_lambda_powertools import Logger, Tracer

logger = Logger()
tracer = Tracer()
zip_file_name="property_images.zip"
url = f"https://ws-assets-prod-iad-r-iad-ed304a55c2ca1aee.s3.us-east-1.amazonaws.com/9a27e484-7336-4ed0-8f90-f2747e4ac65c/{zip_file_name}"
temp_zip_download_location = f"/tmp/{zip_file_name}"
DESTINATION_BUCKET = os.environ['DESTINATION_BUCKET']
s3 = boto3.resource('s3')

@tracer.capture_method
@logger.inject_lambda_context(log_event=True)
def create(event, context):
    image_bucket_name = DESTINATION_BUCKET
    bucket = s3.Bucket(image_bucket_name)
    logger.info(f"downloading zip file from: {url} to: {temp_zip_download_location}")
    r = urlopen(url).read()
    with open(temp_zip_download_location, 'wb') as t:
        t.write(r)
        logger.info('zip file downloaded')

    logger.info(f"unzipping file: {temp_zip_download_location}")
    with zipfile.ZipFile(temp_zip_download_location,'r') as zip_ref:
        zip_ref.extractall('/tmp')
    
    logger.info('file unzipped')
    
    #### upload to s3
    for root,_,files in os.walk('/tmp/property_images'):
        for file in files:
            logger.info(f"file: {os.path.join(root, file)}")
            logger.info(f"s3 bucket: {image_bucket_name}")
            bucket.upload_file(os.path.join(root, file), file)

@tracer.capture_method
def delete(event, context):
    image_bucket_name = DESTINATION_BUCKET
    img_bucket = s3.Bucket(image_bucket_name)
    img_bucket.objects.delete()
    img_bucket.delete()
        
@tracer.capture_method
def lambda_handler(event, context):
    try:
        if event['RequestType'] in ['Create', 'Update']:
            create(event, context)
        elif event['RequestType'] in ['Delete']:
            delete(event, context)
    except Exception as e:
        raise(e)