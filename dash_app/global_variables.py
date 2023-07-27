from datetime import datetime, date, timedelta
import logging
import os
from mysql.connector import pooling
from mysql.connector import Error


# Get the current date and time
current_datetime = datetime.now()

yesterday = date.today() - timedelta(days=1)

# var contains min and max default dates
start_date_string = '2020-09-23'
end_date_string = yesterday.strftime('%Y-%m-%d')

# Format the date in the desired format
date_string = current_datetime.strftime("%Y-%m-%d")

# Append the formatted date to the log file name
log_file_name = f"./app_log_{date_string}.txt"


# basic loggin configuration
logging.basicConfig(
    level=logging.INFO,  # Set the desired log level (e.g., logging.INFO, logging.DEBUG)
    format='%(asctime)s [%(levelname)s] %(message)s',  # Set the log message format
    filename=log_file_name,  # Set the log file path
    filemode='a'  # Set the file mode: 'a' for append, 'w' for overwrite
)


