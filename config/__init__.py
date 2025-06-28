"""
Configuration module for the application.
Provides access to configuration values from default_config.py and environment variables.
"""
from .default_config import *
import os
import logging
import re
from datetime import datetime, time

# Initialize logging
def setup_logging(service_name):
    """
    Set up logging for the specified service.
    
    Args:
        service_name (str): Name of the service (e.g., 'backend', 'flask_dash_app')
    
    Returns:
        logging.Logger: Configured logger instance
    """
    log_file = LOGGING_CONFIG["backend_log_file"] if service_name == "backend" else LOGGING_CONFIG["app_log_file"]
    
    # Ensure logs directory exists
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    
    # Configure logging
    logging.basicConfig(
        level=getattr(logging, LOGGING_CONFIG["level"]),
        format=LOGGING_CONFIG["format"],
        filename=log_file,
        filemode=LOGGING_CONFIG["filemode"]
    )
    
    return logging.getLogger(service_name)

# Utility functions that were previously in global_variables
def format_date_for_db(date_de):
    """
    Convert a date from DD.MM.YYYY format to YYYY-MM-DD format for database use.
    
    Args:
        date_de (str): Date in DD.MM.YYYY format
    
    Returns:
        str: Date in YYYY-MM-DD format
    """
    date_splitted = date_de.split(".")
    year = date_splitted[2]
    month = date_splitted[1]
    day = date_splitted[0]

    date_db_formatted = year + "-" + month + "-" + day
    
    return date_db_formatted

# Set pattern for armband code
ARMBAND_PATTERN = re.compile(r'^[A-Z0-9]{16}$')

def is_valid_armband_code(s):
    """
    Check if a string is a valid armband code.
    
    Args:
        s (str): String to check
    
    Returns:
        bool: True if the string is a valid armband code, False otherwise
    """
    return bool(ARMBAND_PATTERN.match(s))

def check_end_times():
    """
    Determine the end time for recording based on the day of the week.
    
    Returns:
        datetime.time: End time for recording
    """
    day = datetime.today().weekday()
    
    if day == 3:  # Thursday
        return datetime.strptime(TIME_CONFIG["thursday_stop_time"], "%H:%M:%S").time()
    elif day == 1:  # Closed day
        return datetime.strptime(TIME_CONFIG["closed_day_stop_time"], "%H:%M:%S").time()
    else:  # Regular day
        return datetime.strptime(TIME_CONFIG["regular_stop_time"], "%H:%M:%S").time()

# Parse the start time once
SUB_START_TIME = datetime.strptime(TIME_CONFIG["sub_start_time"], "%H:%M:%S").time()