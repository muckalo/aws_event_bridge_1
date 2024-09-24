import json


def lambda_handler(event, context):
    # Log the event data
    print("Received event: " + json.dumps(event))

    # Process the S3 object (you can add your logic here)
    processed_data_list = []
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        print(f"Bucket: {bucket}, Key: {key}")
        processed_data = {"bucket": bucket, "key": key}
        processed_data_list.append(processed_data)

    return {
        'statusCode': 200,
        # 'body': json.dumps('Processing complete!')
        'body': json.dumps(processed_data_list)
    }
