"""
Main entry point for the backend application.
Handles MQTT subscription and data processing.
"""
from multiprocessing import Process
import mqtt_subscribe_callback
import config
from datetime import datetime
import time
from utils import mqtt_client, db
import scans_to_db

# Set up logging
logger = config.setup_logging("backend")

def scan_parser_process_wrapper():
    """Wrapper for the scan parser process to handle exceptions."""
    try:
        scans_to_db.process_daily_scans()
    except ValueError as e:
        logger.error("ERROR occurred in process_daily_scans: %s", e)
    except Exception as e:
        logger.exception("EXCEPTION in process_daily_scans")


def scan_listener_wrapper():
    """Wrapper for the MQTT scan listener to handle exceptions."""
    try:
        mqtt_client.subscribe_to_topic(
            mqtt_subscribe_callback.on_scan,
            config.MQTT_CONFIG["topic"],
            config.MQTT_CONFIG["broker_address"]
        )
    except Exception as e:
        logger.exception("EXCEPTION in Scan Listener")


logger.info("Starting Backend...")
logger.info(f"Recording broker traffic subscribed to: {config.MQTT_CONFIG['topic']}")

if __name__ == '__main__':
    # Initialize database connection pool
    db.init_db_pool("db_pool_backend", 5)
    
    # Listen for scans in the exhibition process
    scan_listener_process = Process(target=scan_listener_wrapper, args=())

    # Process for storing daily scans to database at the end of each day
    parse_daily_scans = Process(target=scan_parser_process_wrapper, args=())

    # Start the listener
    scan_listener_process.start()

    # Start the db scan parser
    parse_daily_scans.start()