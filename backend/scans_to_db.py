"""
Module for processing daily scans and storing them in the database.
"""
import config
from datetime import datetime
import time
from utils import db
import os

# Set up logging
logger = config.setup_logging("backend")

def process_daily_scans():
    """
    Process daily scans from log files and store them in the database.
    This function runs in a loop, checking for the right time to process scans.
    """
    logger.info("%s function was called...", process_daily_scans.__name__)
    
    # Ensure the database connection pool is initialized
    try:
        # Use the shared database connection pool
        pool_name = db.init_db_pool("db_pool_scans_processing", 1).pool_name
        logger.info("Successfully connected to database pool: %s", pool_name)
    except Exception as e:
        logger.exception("Exception while creating pool for function %s: %s", 
                         process_daily_scans.__name__, e)
        return  # Exit the function if we can't connect to the database

    # Counter for tries to insert duplicate code/station combinations per day
    multiple_scan_combi_counter = 0
    
    # Ensure directories exist for log files
    os.makedirs(os.path.dirname(config.FILE_PATHS["daily_scans_file"]), exist_ok=True)
    
    while True:
        # Get current datetime and time
        now = datetime.now()
        current_time = now.time()
        stop_time = config.check_end_times()
        
        logger.info("Current time: %s, Stop time: %s", current_time, stop_time)
        if current_time > stop_time:
            logger.info("Parsing daily scans to DB...")
            
            try:
                # Use our database utility functions with context managers
                with db.get_db_connection() as connection:
                    db_info = connection.get_server_info()
                    logger.info("Successfully connected to MySQL Server: %s", db_info)
                    
                    with db.get_db_cursor(connection) as cursor:
                        # Open the token log file for reading
                        with open(config.FILE_PATHS["daily_scans_file"], "r+") as file:
                            lines = file.readlines()
                            
                            # Process each line
                            for line in lines:
                                try:
                                    # Split the line into its components
                                    parts = line.strip().split("__")
                                    scan_date = config.format_date_for_db(parts[0].split("_")[0])
                                    scan_time = parts[0].split("_")[1]
                                    station_id = parts[1].split("/")[1]
                                    band_code = parts[1].split('"')[1].strip()
                                    
                                    # Validate the data
                                    scan_time_obj = datetime.strptime(scan_time, "%H:%M:%S").time()
                                    if (config.is_valid_armband_code(band_code) and 
                                        scan_time_obj > config.SUB_START_TIME and 
                                        scan_time_obj < stop_time):
                                        
                                        # Construct and execute the SQL query
                                        query = """
                                            INSERT INTO scans 
                                            (scan_date, scan_time, scan_station_id, scan_band_code) 
                                            VALUES (%s, %s, %s, %s)
                                        """
                                        values = (scan_date, scan_time, station_id, band_code)
                                        cursor.execute(query, values)
                                    else:
                                        logger.debug("Invalid armband code or time: %s, %s", band_code, scan_time)
                                        multiple_scan_combi_counter += 1
                                except ValueError as e:
                                    logger.error("Error at scan string processing: %s", e)
                                except Exception as e:
                                    #logger.exception("Exception at scan string processing")
                                    multiple_scan_combi_counter += 1
                            
                            # Commit all changes at once
                            connection.commit()
                            
                            # Clear the file after processing
                            file.seek(0)
                            file.truncate(0)
            
            except Exception as e:
                logger.exception("Exception during scan processing")
            
            logger.info("Parsing Token Scans Completed Successfully!")
            logger.info("After today's parsing of scans in DB number of excessive/multiple scans is: %s", 
                       multiple_scan_combi_counter)
            logger.info("Waiting 12 hours until checking time for parsing token scans again...")
            
            # Reset counter and sleep
            multiple_scan_combi_counter = 0
            time.sleep(43200)  # 12 hours
        else:
            # Check again in a minute
            time.sleep(60)
        
