import functions_framework
from google.cloud import storage
import os
import json
from datetime import datetime

@functions_framework.http
def run_airline_pipeline(request):
    """
    Cloud Function to trigger the data pipeline
    """
    try:
        # Get parameters from request
        request_json = request.get_json(silent=True)
        year = request_json.get('year', datetime.now().year)
        months = request_json.get('months', [datetime.now().month])
        
        # Initialize pipeline
        bucket_name = os.environ.get('BUCKET_NAME')
        mongodb_uri = os.environ.get('MONGODB_URI')
        
        print(f"main 1: bucket_name is {bucket_name}")
        print(f"main 2: mongodb_uri is {mongodb_uri}")
        print(f"main 3: year is {year}")
        print(f"main 4: months is {months}")
        

        # Import and run pipeline
        from airline_pipeline import AirlineDataPipeline
        
        pipeline = AirlineDataPipeline(bucket_name, mongodb_uri)
        result = pipeline.run_pipeline(year, months)
        
        return {
            'status': 'success',
            'message': f'Pipeline executed for year {year}, months {months}',
            'result': result
        }, 200
        
    except Exception as e:
        return {
            'status': 'error',
            'message': str(e)
        }, 500

# Alternatively, use a Cloud Scheduler triggered function
@functions_framework.cloud_event
def scheduled_pipeline(cloud_event):
    """
    Cloud Function triggered by Cloud Scheduler
    """
    try:
        bucket_name = os.environ.get('BUCKET_NAME')
        mongodb_uri = os.environ.get('MONGODB_URI')
        
        # Get current month and year for automated processing
        current_year = datetime.now().year
        current_month = datetime.now().month
        
        pipeline = AirlineDataPipeline(bucket_name, mongodb_uri)
        result = pipeline.run_pipeline(current_year, [current_month])
        
        print(f"Scheduled pipeline executed successfully for {current_year}-{current_month}")
        return result
        
    except Exception as e:
        print(f"Error in scheduled pipeline: {str(e)}")
        raise e
