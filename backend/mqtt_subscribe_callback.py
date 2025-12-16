"""
MQTT callback functions for handling subscription messages.
"""
from datetime import datetime
import time
import config
import os
from multiprocessing import Process

# Set up logging
logger = config.setup_logging("backend")

# Ensure directories exist for log files
os.makedirs(os.path.dirname(config.FILE_PATHS["daily_scans_file"]), exist_ok=True)
os.makedirs(os.path.dirname(config.FILE_PATHS["scans_archive_file"]), exist_ok=True)

def on_scan(client, stop, message):
    """
    Callback function for MQTT subscription to handle scan events.
    
    Args:
        client: MQTT client instance
        stop: Stop flag
        message: MQTT message
    """
    # Get current datetime and time
    now = datetime.now()
    current_time = now.time()
    stop_time = config.check_end_times()

    # Open log files
    daily_scans_file = open(config.FILE_PATHS["daily_scans_file"], "a")
    scans_archive_file = open(config.FILE_PATHS["scans_archive_file"], "a")

    if current_time > config.SUB_START_TIME and current_time < stop_time:
        # Get current time and date
        formatted_date_time = now.strftime("%d.%m.%Y_%H:%M:%S")
        
        # Write the token scan messages to daily_report file and archive file
        daily_scans_file.write(formatted_date_time + "__" + ("%s %s" % (message.topic, message.payload)) + "\n")
        scans_archive_file.write(formatted_date_time + "__" + ("%s %s" % (message.topic, message.payload)) + "\n")
    else:
        # Log info about invalid time window if needed
        # logger.debug("Scan in invalid time window occurred")
        pass
    
    # Close files
    daily_scans_file.close()
    scans_archive_file.close()
