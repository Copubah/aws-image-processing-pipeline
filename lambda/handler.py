import json
import os
import logging
import boto3
from io import BytesIO
from PIL import Image
from botocore.exceptions import ClientError

logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(getattr(logging, log_level))

s3_client = boto3.client('s3')

PROCESSED_BUCKET = os.environ['PROCESSED_BUCKET']
IMAGE_WIDTH = int(os.environ.get('IMAGE_WIDTH', 800))
IMAGE_HEIGHT = int(os.environ.get('IMAGE_HEIGHT', 600))

MAX_IMAGE_SIZE = 50 * 1024 * 1024
ALLOWED_FORMATS = {'JPEG', 'PNG', 'GIF', 'BMP', 'WEBP'}


def lambda_handler(event, context):
    batch_item_failures = []
    processed_count = 0
    
    for record in event['Records']:
        try:
            message_body = json.loads(record['body'])
            
            for s3_record in message_body['Records']:
                bucket_name = s3_record['s3']['bucket']['name']
                object_key = s3_record['s3']['object']['key']
                
                logger.info(f"Processing image: {object_key} from bucket: {bucket_name}")
                
                process_image(bucket_name, object_key)
                processed_count += 1
                
        except Exception as e:
            logger.error(f"Error processing record: {str(e)}", exc_info=True)
            batch_item_failures.append({
                'itemIdentifier': record['messageId']
            })
    
    logger.info(f"Successfully processed {processed_count} images")
    
    return {
        'batchItemFailures': batch_item_failures
    }


def process_image(bucket_name, object_key):
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        
        content_length = response['ContentLength']
        if content_length > MAX_IMAGE_SIZE:
            raise ValueError(f"Image size {content_length} exceeds maximum {MAX_IMAGE_SIZE}")
        
        image_data = response['Body'].read()
        metadata = response.get('Metadata', {})
        
        image = Image.open(BytesIO(image_data))
        
        if image.format not in ALLOWED_FORMATS:
            raise ValueError(f"Unsupported image format: {image.format}")
        
        logger.info(f"Original image - Format: {image.format}, Size: {image.size}, Mode: {image.mode}")
        
        if image.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', image.size, (255, 255, 255))
            if image.mode == 'P':
                image = image.convert('RGBA')
            background.paste(image, mask=image.split()[-1] if image.mode in ('RGBA', 'LA') else None)
            image = background
        elif image.mode != 'RGB':
            image = image.convert('RGB')
        
        resized_image = image.resize((IMAGE_WIDTH, IMAGE_HEIGHT), Image.LANCZOS)
        
        output_buffer = BytesIO()
        image_format = image.format if image.format else 'JPEG'
        
        save_kwargs = {'format': image_format, 'quality': 85, 'optimize': True}
        if image_format == 'JPEG':
            save_kwargs['progressive'] = True
        
        resized_image.save(output_buffer, **save_kwargs)
        output_buffer.seek(0)
        
        processed_key = f"processed/{object_key}"
        
        content_type = get_content_type(image_format)
        
        s3_client.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=processed_key,
            Body=output_buffer.getvalue(),
            ContentType=content_type,
            Metadata={
                'original-bucket': bucket_name,
                'original-key': object_key,
                'original-size': str(content_length),
                'processed-size': str(output_buffer.tell())
            },
            ServerSideEncryption='AES256'
        )
        
        logger.info(f"Successfully processed and uploaded: {processed_key}")
        
    except ClientError as e:
        logger.error(f"AWS error processing image {object_key}: {e.response['Error']['Code']}")
        raise
    except Exception as e:
        logger.error(f"Error processing image {object_key}: {str(e)}")
        raise


def get_content_type(image_format):
    content_types = {
        'JPEG': 'image/jpeg',
        'JPG': 'image/jpeg',
        'PNG': 'image/png',
        'GIF': 'image/gif',
        'BMP': 'image/bmp',
        'WEBP': 'image/webp'
    }
    return content_types.get(image_format.upper(), 'image/jpeg')
