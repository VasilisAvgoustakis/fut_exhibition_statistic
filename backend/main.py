from multiprocessing import Process
import mqtt_subscribe_callback #contains callback functions for sub.callback
import global_variables as gv #contains all global variables and file paths
from datetime import datetime
import time
import paho.mqtt.subscribe as sub
import scans_to_db, assets_to_db, process_times


def times_parser_process_wrapper():
    try:
        process_times.process_scan_times()
    except ValueError as e:
        gv.logging.error("ERROR occured in process_scan_times: %s", e)
    except Exception as e:
        gv.logging.exception("EXCEPTION  occured in proccess_scan_times: %s", e)

def scan_parser_process_wrapper():
    try:
        scans_to_db.process_daily_scans()
    except ValueError as e:
         gv.logging.error("ERROR occurred in process_daily_scans: %s", e)
    except Exception as e:
        gv.logging.exception("EXCEPTION  in process_daily_scans: ")

def asset_parser_process_wrapper():
    try:
        assets_to_db.process_daily_asset_calls()
    except ValueError as e:
         gv.logging.error("ERROR occurred in process_daily_asset_calls: %s", e)
    except Exception as e:
        gv.logging.exception("EXCEPTION  in process_daily_asset_calls: ")

def scan_listener_wrapper():
    try:
        sub.callback(mqtt_subscribe_callback.on_scan, "tokenStations/+/onScan", hostname= broker_address)
    except Exception as e:
        gv.logging.exception("EXCEPTION in Scan Listener: ")

gv.logging.info("Starting Backend...")

gv.logging.info("Recording broker trafic subscribed to: tokenStations/+/onScan") # "+" is a wildcard
if __name__ == '__main__':
    broker_address = "172.25.2.56"  #set the Broker address
    # listen for scans in the exhibition process
    scan_listener_process = Process(target=scan_listener_wrapper, args=())

    # process for storing daily scans to database at the end of each day
    parse_daily_scans = Process(target=scan_parser_process_wrapper, args=())

    # process for storing daily asset calls in DB at end of each day
    parse_daily_asset_calls = Process(target=asset_parser_process_wrapper, args=())

    # Process for processing daily time scans
    process_daily_times = Process(target=times_parser_process_wrapper, args=())

    #start the listener
    #scan_listener_process.start()

    # start the db scan parser
    #parse_daily_scans.start()
    
    # start the db asset parser
    #parse_daily_asset_calls.start()

    # start the time processesing
    process_daily_times.start()