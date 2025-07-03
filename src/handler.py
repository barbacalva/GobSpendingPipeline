import os
import json
import boto3
import datetime

s3 = boto3.client("s3")
BUCKET = os.environ["TARGET_BUCKET"]


def lambda_handler(event, context):
    key = f"lambda-smoke/{datetime.datetime.utcnow().isoformat()}.json"
    body = {
        "msg": "¡Funciona! La Lambda tiene permiso de escritura.",
        "timestamp": datetime.datetime.utcnow().isoformat()
    }

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=json.dumps(body).encode(),
        ContentType="application/json"
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"written_key": key})
    }
