# bts-data-pipeline
This project implements a scalable, reproducible big data pipeline for processing U.S. airline flight data using modern cloud technologies (GCP) and NoSQL databases.

## Architecture Overview

The pipeline uses the following GCP services:
- **Google Cloud Storage (GCS)**: Data lake for raw and processed data
- **Cloud Functions**: Serverless compute for pipeline orchestration
- **Compute Engine**: MongoDB database and Jupyter instance
- **Cloud Scheduler**: Automated pipeline execution

## Prerequisites

1. GCP Project with billing enabled
2. gcloud CLI installed and configured
3. Python 3.9+
4. MongoDB experience (basic)

## Project Structure

```
airline-pipeline/
├── src/                    # Source code for the pipeline
│   └── airline_pipeline.py
├── functions/              # Cloud Functions code
│   ├── main.py
├── notebooks/              # Jupyter notebooks for analysis
│   └── analysis.ipynb
```

## Setup Instructions

### 1. Initial GCP Setup

```bash
# Set Up GCP Environment
chmod +x gcp-setup.sh
./gcp-setup.sh

# Set up MongoDB
## SSH into the VM
gcloud compute ssh <your_vm_name> --zone=us-central1-a

# Run the MongoDB installation script (after uploading it to the VM)
chmod +x mongodb-install.sh
./mongodb-install.sh

# Install Jupyter and needed dependencies
## SSH into the VM
gcloud compute ssh <your_vm_name> --zone=us-central1-a

# Run the Jupyter installation script (after uploading it to the VM)
chmod +x jupyter-install.sh
./jupyter-install.sh
```

### 2. Deploy the Pipeline

```bash
# Create local project structure
mkdir -p airline-pipeline/{src,functions,notebooks,configs}

# Copy the scripts we created to the appropriate directories
  ## Save the python code to airline-pipeline/src/airline_pipeline.py
  ## Save the cloud function code to airline-pipeline/functions/main.py
  ## Save the notebook to airline-pipeline/notebooks/analysis_notebook.ipynb

# Run the deployment script
chmod +x deploy-pipeline.sh
./deploy-pipeline.sh
```

### 3. Manual Trigger (optional to verify)

```bash
# Trigger the pipeline manually
curl -X POST "https://{your_function_endpoint_url}/" \
  -H "Content-Type: application/json" \
  -d '{"year": 2024, "months": [10,11,12]}'

# Check if data was uploaded to GCS
gsutil ls gs://<your_bucket>/cleaned_data/

# Connect to MongoDB and check if documents were inserted
gcloud compute ssh <your_vm_name> --zone=us-central1-a
## Commands:
mongosh
use airline_db
show collections
db.flights.find().limit(5).pretty()
db.flights.countDocuments()
```

### 4. Access Jupyter notebook
```bash
URL: http://<your_vm_public_ip>:8888/?token=<your_jupyter_token>
```

## Data Flow

1. **Ingestion**: Data downloaded from BTS website to GCS raw bucket
2. **Cleaning**: Data cleaned and standardized to GCS processed bucket
3. **Transformation**: Data transformed into MongoDB documents
4. **Storage**: Documents loaded into MongoDB with indexes
5. **Analysis**: Jupyter notebooks analyze data with visualizations

## MongoDB Schema

```json
{
  "flight_info": {
    "flight_number": "123",
    "airline": "AA",
    "date": "2023-01-01T00:00:00Z"
  },
  "airport_info": {
    "origin": "ATL",
    "destination": "LAX"
  },
  "delay_info": {
    "total_delay": 15,
    "carrier_delay": 5,
    "weather_delay": 10,
    "nas_delay": 0,
    "security_delay": 0,
    "late_aircraft_delay": 0
  },
  "status_flags": {
    "cancelled": false,
    "diverted": false
  },
  "metadata": {
    "inserted_at": "2025-01-01T00:00:00Z",
    "processed_at": "2025-01-01T00:00:00Z"
  }
}
```

## Key Features

1. **Scalability**: Handles millions of records with MongoDB and GCS
2. **Reproducibility**: Complete pipeline documented and version controlled
3. **Automation**: Scheduled execution with Cloud Scheduler
4. **Data Quality**: Comprehensive cleaning and validation
5. **Analysis**: Jupyter notebooks with visualizations

## Usage Examples

### Query MongoDB

```python
# Find delayed flights
delayed_flights = collection.find({
    "delay_info.total_delay": {"$gt": 15}
})

# Get average delays by airline
pipeline = [
    {"$group": {
        "_id": "$flight_info.airline",
        "avg_delay": {"$avg": "$delay_info.total_delay"}
    }}
]
```

### Run Pipeline Manually

```bash
# Process specific months
curl -X POST \
  https://{your_function_endpoint_base_url}/process-airline-data \
  -H 'Content-Type: application/json' \
  -d '{"year": 2024, "months": [10,11,12]}'
```

## Monitoring

1. **Cloud Functions Logs**: Monitor pipeline execution
2. **GCS Metrics**: Track storage usage
3. **MongoDB Metrics**: Monitor query performance

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This project is licensed under the individual owning this repository.

## References

- [Bureau of Transportation Statistics](https://www.transtats.bts.gov/)
- [MongoDB Documentation](https://www.mongodb.com/docs/)
- [Google Cloud Documentation](https://cloud.google.com/docs)


