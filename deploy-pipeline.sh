#!/bin/bash

# BTS Data Data Pipeline Deployment Script for GCP
# =============================================

# Set variables
PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="${PROJECT_ID}-airline-data"
REGION="us-central1"
MONGODB_INTERNAL_IP="<your_vm_internal_ip>"
SA_EMAIL=bts-data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com

# Create requirements.txt for Cloud Function
cat > bts-data-pipeline/functions/requirements.txt << EOF
functions-framework==3.3.0
google-cloud-storage==2.10.0
pymongo==4.3.3
numpy==1.22.4
pandas==1.4.4
EOF

# Create requirements.txt for main pipeline
cat > bts-data-pipeline/requirements.txt << EOF
google-cloud-storage==2.10.0
pymongo==4.3.3
pandas==1.4.4
requests==2.31.0
numpy==1.22.4
matplotlib==3.7.2
seaborn==0.12.2
jupyter==1.0.0
EOF

# Create Firebase configuration for triggering
cat > bts-data-pipeline/configs/firebase.json << EOF
{
  "functions": {
    "source": "functions"
  }
}
EOF

# Deploy Cloud Function
cd bts-data-pipeline/functions

# First, make sure airline_pipeline.py is available in the function directory
cp ../src/airline_pipeline.py .

# Deploy with verbose logging and added flags
gcloud functions deploy process-airline-data \
    --runtime python39 \
    --trigger-http \
    --entry-point run_airline_pipeline \
    --region ${REGION} \
    --vpc-connector=vpc-mongo-connector \
    --set-env-vars BUCKET_NAME=${BUCKET_NAME},MONGODB_URI=mongodb://${MONGODB_INTERNAL_IP}:27017/ \
    --memory 4096MB \
    --timeout 540s \
    --allow-unauthenticated \
    --verbosity=debug

## Create Cloud Scheduler job for automated pipeline
gcloud scheduler jobs create http bts-data-pipeline-scheduler \
    --location=${REGION} \
    --schedule="0 1 * * *" \
    --uri="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/process-airline-data" \
    --http-method=POST \
    --message-body='{"year": 2023, "months": [1,2,3,4,5,6]}' \
    --oidc-service-account-email=${SA_EMAIL}

echo "Deployment complete!"
echo "Cloud Function URL: https://${REGION}-${PROJECT_ID}.cloudfunctions.net/process-airline-data"
echo "MongoDB instance: ${MONGODB_INTERNAL_IP}"
echo "Bucket: gs://${BUCKET_NAME}"