import os
import io
import requests
import pandas as pd
import pymongo
import json
from google.cloud import storage
from datetime import datetime
import hashlib
import zipfile

class AirlineDataPipeline:
    def __init__(self, bucket_name, mongodb_uri):
        self.bucket_name = bucket_name
        self.mongodb_uri = mongodb_uri
        self.storage_client = storage.Client()
        self.bucket = self.storage_client.bucket(bucket_name)
        
    def download_bts_data(self, year, months):
        """
        Download BTS data from source to GCS bucket
        Simulates download from BTS website
        """
        base_url = "https://www.transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present"
        
        for month in months:
            filename = f"{year}_{month}.zip"
            #Download from BTS
            print(f"Downloading {filename} from BTS")
            
            response = requests.get(f"{base_url}_{filename}")
            
            if response.status_code != 200:
                print(f"Failed to download {filename} from BTS")
            else:
                print(f"Successfully downloaded {filename} from BTS")

            blob = self.bucket.blob(f"raw_data/{filename}")
            blob.upload_from_string(response.content, content_type='application/zip')
            print(f"Uploaded {filename} to GCS")
        
    def clean_data(self, input_path, output_path=None):
        """
        Clean and standardize airline data
        """
        # Read from GCS
        blob = self.bucket.blob(input_path)
        zip_bytes = blob.download_as_bytes()

        # Extract CSV from ZIP
        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as z:
            csv_filename = z.namelist()[0]  # Assumes only one CSV in the ZIP
            with z.open(csv_filename) as f:
                # Convert to pandas DataFrame
                df = pd.read_csv(f, low_memory=False)
        
        # Data cleaning steps
        df.rename(columns={
            'Reporting_Airline': 'carrier',
            'Flight_Number_Reporting_Airline': 'flightnum'
        }, inplace=True)

        critical_fields = ['FlightDate', 'Origin', 'Dest', 'carrier', 'flightnum']
        df_clean = df.dropna(subset=critical_fields)
        # Impute delay values
        delay_fields = [
            'DepDelay', 'ArrDelay', 'CarrierDelay', 
            'WeatherDelay', 'NASDelay', 'SecurityDelay',
            'LateAircraftDelay'
        ]
        for field in delay_fields:
            if field in df_clean.columns:
                df_clean[field] = df_clean[field].fillna(0)
        
        # Remove outliers
        for field in delay_fields:
            if field in df_clean.columns:
                df_clean = df_clean[df_clean[field] >= 0]
                df_clean = df_clean[df_clean[field] < 1440]  # Less than 24 hours
        
        # Standardize fields
        df_clean['FlightDate'] = pd.to_datetime(df_clean['FlightDate'])
        df_clean.columns = df_clean.columns.str.lower().str.strip()
        
        # Save cleaned data to GCS
        if output_path is None:
            output_path = input_path.replace('raw_data/', 'cleaned_data/')
        
        cleaned_json = df_clean.to_json(orient='records', date_format='iso')
        blob = self.bucket.blob(output_path)
        blob.upload_from_string(cleaned_json)

        print(f"Cleaned data uploaded to {output_path}")
        return df_clean
    
    def transform_for_mongodb(self, df):
        """
        Transform data for MongoDB document structure
        """
        documents = []
        
        for _, row in df.iterrows():
            document = {
                'flight_info': {
                    'flight_number': row.get('flightnum'),
                    'airline': row.get('carrier'),
                    'date': row.get('flightdate')
                },
                'airport_info': {
                    'origin': row.get('origin'),
                    'destination': row.get('dest')
                },
                'delay_info': {
                    'total_delay': row.get('arrdelay', 0),
                    'carrier_delay': row.get('carrierdelay', 0),
                    'weather_delay': row.get('weatherdelay', 0),
                    'nas_delay': row.get('nasdelay', 0),
                    'security_delay': row.get('securitydelay', 0),
                    'late_aircraft_delay': row.get('lateaircraftdelay', 0)
                },
                'status_flags': {
                    'cancelled': row.get('cancelled', False),
                    'diverted': row.get('diverted', False)
                },
                'metadata': {
                    'inserted_at': datetime.utcnow(),
                    'processed_at': datetime.utcnow()
                }
            }
            documents.append(document)
        
        return documents
    
    def load_to_mongodb(self, documents, collection_name='flights'):
        """
        Load transformed data to MongoDB
        """
        client = pymongo.MongoClient(self.mongodb_uri)
        db = client['airline_db']
        collection = db[collection_name]
        
        # Insert documents in batches
        batch_size = 1000
        for i in range(0, len(documents), batch_size):
            batch = documents[i:i + batch_size]
            collection.insert_many(batch)
        
        # Create indexes for efficient querying
        collection.create_index([('flight_info.airline', 1)])
        collection.create_index([('airport_info.origin', 1)])
        collection.create_index([('flight_info.date', 1)])
        
        client.close()
        
        return len(documents)
    
    def run_pipeline(self, year, months):
        """
        Run complete pipeline
        """
        # Step 1: Download data
        print(f"pipeln 1: bts download to bucket start")
        self.download_bts_data(year, months)
        print(f"pipeln 2: bts download to bucket end")
        
        # Step 2: Clean each month's data
        for month in months:
            input_path = f"raw_data/{year}_{month}.zip"
            print(f"pipeln 3: cleansing start")
            df_clean = self.clean_data(input_path)
            print(f"pipeln 4: cleansing end")
            
            # Step 3: Transform for MongoDB
            print(f"pipeln 5: mdb transform start")
            documents = self.transform_for_mongodb(df_clean)
            print(f"pipeln 6: mdb transform end")
            
            # Step 4: Load to MongoDB
            print(f"pipeln 7: mdb load start")
            count = self.load_to_mongodb(documents)
            print(f"Loaded {count} documents for {year}_{month}")
        
        return True

# Usage example
if __name__ == "__main__":
    BUCKET_NAME = "your-project-airline-data"
    MONGODB_URI = "mongodb://your-mongodb-vm-ip:27017/"
    
    pipeline = AirlineDataPipeline(BUCKET_NAME, MONGODB_URI)
    pipeline.run_pipeline(2023, range(1, 7))  # Run for Jan-Jun 2023
