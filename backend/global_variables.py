from datetime import datetime
import logging
import os
from mysql.connector import pooling
from mysql.connector import Error
import re


# Get the current date and time
current_datetime = datetime.now()

# Format the date in the desired format
date_string = current_datetime.strftime("%Y-%m-%d")

# Append the formatted date to the log file name
log_file_name = f"./logs/backend_log_{date_string}.txt"


# basic loggin configuration
logging.basicConfig(
    level=logging.INFO,  # Set the desired log level (e.g., logging.INFO, logging.DEBUG)
    format='%(asctime)s [%(levelname)s] %(message)s',  # Set the log message format
    filename=log_file_name,  # Set the log file path
    filemode='a'  # Set the file mode: 'a' for append, 'w' for overwrite
)

##

#network traffic files
#scans
daily_scans_file = "./network_traffic_archives/token_daily_log.txt"
scans_archive_file = "./network_traffic_archives/token_archive_log.txt"

#assets
daily_asset_log = "./network_traffic_archives/access.log"



######Time System
sub_start_time = datetime.strptime("10:00:00", "%H:%M:%S").time()

def checkEndTimes():
    day = datetime.today().weekday()
    now = datetime.now().time()

    if day == 3 :
        #logging.info("Thursday")

        sub_stop_time = datetime.strptime("20:00:00", "%H:%M:%S").time() # count asset recalls from this time onward ...set later at 19:59

    elif day == 1:
        #logging.info("Schließtag")
        sub_stop_time = datetime.strptime("09:00:00", "%H:%M:%S").time()# set that back to 9:00

    else:
        #logging.info("Regular day")
        sub_stop_time = datetime.strptime("18:00:00", "%H:%M:%S").time()

    return sub_stop_time

def format_date_for_db(date_de):
    date_splitted = date_de.split(".")
    year = date_splitted[2]
    month = date_splitted[1]
    day = date_splitted[0]

    date_db_formatted = year + "-" + month + "-" + day

    
    return date_db_formatted

# set pattern for armband code
pattern = re.compile(r'^[A-Z0-9]{16}$')

def is_valid_armband_code(s):
    return bool(pattern.match(s))