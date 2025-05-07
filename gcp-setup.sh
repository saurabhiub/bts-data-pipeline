# GCP Environment Setup Script
# Run this script to set up your GCP environment for the airline data pipeline
# Set your variables
gcloud config set project <your_project>
PROJECT_ID=$(gcloud config get-value project)
SA_EMAIL=bts-data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com
BUCKET_NAME="${PROJECT_ID}-airline-data"

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable cloudrun.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable dataproc.googleapis.com

# Create a service account for the project
gcloud iam service-accounts create bts-data-pipeline-sa \
    --display-name="Airline Pipeline Service Account"

# Grant necessary permissions
PROJECT_ID=$(gcloud config get-value project)
SA_EMAIL=bts-data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/dataproc.worker"

# Create a Google Cloud Storage bucket for data storage
BUCKET_NAME="${PROJECT_ID}-airline-data"
gsutil mb gs://${BUCKET_NAME}

# Check if the default network exists, if not create it
NETWORK_CHECK=$(gcloud compute networks list --filter="name=default" --format="value(name)" 2>/dev/null)
if [ -z "$NETWORK_CHECK" ]; then
    echo "Default network doesn't exist. Creating it..."
    gcloud compute networks create default --subnet-mode=auto
    
    # Create a firewall rule for SSH
    gcloud compute firewall-rules create default-allow-ssh \
        --network default \
        --allow tcp:22 \
        --source-ranges 0.0.0.0/0
    
    # Create a firewall rule for MongoDB
    gcloud compute firewall-rules create allow-vpc-to-mongo \
        --network=default \
        --allow=tcp:27017 \
        --source-ranges=10.8.0.0/28 \
        --target-tags=mongodb

    # Create a firewall rule for Jupyter
    gcloud compute firewall-rules create allow-jupyter \
        --allow tcp:8888 \
        --target-tags=jupyter \
        --source-ranges=0.0.0.0/0 \
        --network=default

    gcloud compute instances add-tags airline-mongodb \
        --zone=us-central1-a \
        --tags=jupyter
fi

#Apply Tags
gcloud compute instances add-tags airline-mongodb \
  --zone=us-central1-a \
  --tags=mongodb

# Create VPC connector
gcloud compute networks vpc-access connectors create vpc-mongo-connector \
  --region=us-central1 \
  --network=default \
  --range=10.8.0.0/28

gcloud compute firewall-rules create allow-vpc-connector-to-mongo \
  --network=default \
  --allow=tcp:27017 \
  --source-ranges=10.8.0.0/28 \
  --target-tags=mongodb

# Create a Compute Engine instance for MongoDB
gcloud compute instances create airline-mongodb-v1 \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --boot-disk-size=80GB \
    --boot-disk-type=pd-standard \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --service-account=${SA_EMAIL} \
    --scopes=https://www.googleapis.com/auth/cloud-platform

echo "Setup complete! Your environment is ready."
echo "Bucket: gs://${BUCKET_NAME}"
echo "MongoDB instance: airline-mongodb-v1"