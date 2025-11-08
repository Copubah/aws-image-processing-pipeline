import json
import os
import unittest
from unittest.mock import Mock, patch, MagicMock
from io import BytesIO
from PIL import Image
from botocore.exceptions import ClientError
import handler


class TestImageProcessor(unittest.TestCase):
    
    def setUp(self):
        os.environ['PROCESSED_BUCKET'] = 'test-processed-bucket'
        os.environ['IMAGE_WIDTH'] = '800'
        os.environ['IMAGE_HEIGHT'] = '600'
        os.environ['LOG_LEVEL'] = 'INFO'
        
        self.test_event = {
            'Records': [
                {
                    'messageId': 'test-message-id',
                    'body': json.dumps({
                        'Records': [
                            {
                                's3': {
                                    'bucket': {'name': 'test-upload-bucket'},
                                    'object': {'key': 'test-image.jpg'}
                                }
                            }
                        ]
                    })
                }
            ]
        }
        
        self.test_context = Mock()
    
    def create_test_image(self, width=1000, height=1000, mode='RGB', format='JPEG'):
        test_image = Image.new(mode, (width, height), color='red')
        img_buffer = BytesIO()
        test_image.save(img_buffer, format=format)
        img_buffer.seek(0)
        return img_buffer
    
    @patch('handler.s3_client')
    def test_successful_image_processing(self, mock_s3):
        img_buffer = self.create_test_image()
        
        mock_s3.get_object.return_value = {
            'Body': MagicMock(read=lambda: img_buffer.getvalue()),
            'ContentLength': len(img_buffer.getvalue()),
            'Metadata': {}
        }
        
        result = handler.lambda_handler(self.test_event, self.test_context)
        
        self.assertEqual(result['batchItemFailures'], [])
        mock_s3.put_object.assert_called_once()
        
        call_args = mock_s3.put_object.call_args
        self.assertEqual(call_args[1]['Bucket'], 'test-processed-bucket')
        self.assertEqual(call_args[1]['Key'], 'processed/test-image.jpg')
        self.assertEqual(call_args[1]['ContentType'], 'image/jpeg')
        self.assertEqual(call_args[1]['ServerSideEncryption'], 'AES256')
    
    @patch('handler.s3_client')
    def test_png_with_transparency(self, mock_s3):
        img_buffer = self.create_test_image(mode='RGBA', format='PNG')
        
        mock_s3.get_object.return_value = {
            'Body': MagicMock(read=lambda: img_buffer.getvalue()),
            'ContentLength': len(img_buffer.getvalue()),
            'Metadata': {}
        }
        
        result = handler.lambda_handler(self.test_event, self.test_context)
        
        self.assertEqual(result['batchItemFailures'], [])
        mock_s3.put_object.assert_called_once()
    
    @patch('handler.s3_client')
    def test_image_too_large(self, mock_s3):
        img_buffer = self.create_test_image()
        
        mock_s3.get_object.return_value = {
            'Body': MagicMock(read=lambda: img_buffer.getvalue()),
            'ContentLength': 60 * 1024 * 1024,
            'Metadata': {}
        }
        
        result = handler.lambda_handler(self.test_event, self.test_context)
        
        self.assertEqual(len(result['batchItemFailures']), 1)
        self.assertEqual(result['batchItemFailures'][0]['itemIdentifier'], 'test-message-id')
    
    @patch('handler.s3_client')
    def test_unsupported_format(self, mock_s3):
        test_image = Image.new('RGB', (100, 100))
        img_buffer = BytesIO()
        test_image.save(img_buffer, format='TIFF')
        img_buffer.seek(0)
        
        mock_s3.get_object.return_value = {
            'Body': MagicMock(read=lambda: img_buffer.getvalue()),
            'ContentLength': len(img_buffer.getvalue()),
            'Metadata': {}
        }
        
        result = handler.lambda_handler(self.test_event, self.test_context)
        
        self.assertEqual(len(result['batchItemFailures']), 1)
    
    @patch('handler.s3_client')
    def test_s3_client_error(self, mock_s3):
        error_response = {'Error': {'Code': 'NoSuchKey', 'Message': 'Key not found'}}
        mock_s3.get_object.side_effect = ClientError(error_response, 'GetObject')
        
        result = handler.lambda_handler(self.test_event, self.test_context)
        
        self.assertEqual(len(result['batchItemFailures']), 1)
        self.assertEqual(result['batchItemFailures'][0]['itemIdentifier'], 'test-message-id')
    
    @patch('handler.s3_client')
    def test_multiple_records(self, mock_s3):
        img_buffer = self.create_test_image()
        
        multi_event = {
            'Records': [
                {
                    'messageId': 'msg-1',
                    'body': json.dumps({
                        'Records': [
                            {
                                's3': {
                                    'bucket': {'name': 'test-bucket'},
                                    'object': {'key': 'image1.jpg'}
                                }
                            }
                        ]
                    })
                },
                {
                    'messageId': 'msg-2',
                    'body': json.dumps({
                        'Records': [
                            {
                                's3': {
                                    'bucket': {'name': 'test-bucket'},
                                    'object': {'key': 'image2.jpg'}
                                }
                            }
                        ]
                    })
                }
            ]
        }
        
        mock_s3.get_object.return_value = {
            'Body': MagicMock(read=lambda: img_buffer.getvalue()),
            'ContentLength': len(img_buffer.getvalue()),
            'Metadata': {}
        }
        
        result = handler.lambda_handler(multi_event, self.test_context)
        
        self.assertEqual(result['batchItemFailures'], [])
        self.assertEqual(mock_s3.put_object.call_count, 2)
    
    @patch('handler.s3_client')
    def test_partial_batch_failure(self, mock_s3):
        img_buffer = self.create_test_image()
        
        multi_event = {
            'Records': [
                {
                    'messageId': 'msg-success',
                    'body': json.dumps({
                        'Records': [
                            {
                                's3': {
                                    'bucket': {'name': 'test-bucket'},
                                    'object': {'key': 'good-image.jpg'}
                                }
                            }
                        ]
                    })
                },
                {
                    'messageId': 'msg-failure',
                    'body': json.dumps({
                        'Records': [
                            {
                                's3': {
                                    'bucket': {'name': 'test-bucket'},
                                    'object': {'key': 'bad-image.jpg'}
                                }
                            }
                        ]
                    })
                }
            ]
        }
        
        def side_effect(*args, **kwargs):
            if kwargs['Key'] == 'bad-image.jpg':
                raise ValueError("Invalid image")
            return {
                'Body': MagicMock(read=lambda: img_buffer.getvalue()),
                'ContentLength': len(img_buffer.getvalue()),
                'Metadata': {}
            }
        
        mock_s3.get_object.side_effect = side_effect
        
        result = handler.lambda_handler(multi_event, self.test_context)
        
        self.assertEqual(len(result['batchItemFailures']), 1)
        self.assertEqual(result['batchItemFailures'][0]['itemIdentifier'], 'msg-failure')
    
    def test_get_content_type(self):
        self.assertEqual(handler.get_content_type('JPEG'), 'image/jpeg')
        self.assertEqual(handler.get_content_type('JPG'), 'image/jpeg')
        self.assertEqual(handler.get_content_type('PNG'), 'image/png')
        self.assertEqual(handler.get_content_type('GIF'), 'image/gif')
        self.assertEqual(handler.get_content_type('BMP'), 'image/bmp')
        self.assertEqual(handler.get_content_type('WEBP'), 'image/webp')
        self.assertEqual(handler.get_content_type('UNKNOWN'), 'image/jpeg')
        self.assertEqual(handler.get_content_type('jpeg'), 'image/jpeg')
    
    @patch('handler.s3_client')
    def test_metadata_preservation(self, mock_s3):
        img_buffer = self.create_test_image()
        
        mock_s3.get_object.return_value = {
            'Body': MagicMock(read=lambda: img_buffer.getvalue()),
            'ContentLength': len(img_buffer.getvalue()),
            'Metadata': {'custom-key': 'custom-value'}
        }
        
        result = handler.lambda_handler(self.test_event, self.test_context)
        
        self.assertEqual(result['batchItemFailures'], [])
        
        call_args = mock_s3.put_object.call_args
        metadata = call_args[1]['Metadata']
        self.assertIn('original-bucket', metadata)
        self.assertIn('original-key', metadata)
        self.assertIn('original-size', metadata)
        self.assertIn('processed-size', metadata)


if __name__ == '__main__':
    unittest.main()
