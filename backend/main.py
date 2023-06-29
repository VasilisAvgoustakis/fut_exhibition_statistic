from multiprocessing import Process
import mqtt_subscribe_callback #contains callback functions for sub.callback
import global_variables as gv #contains all global variables and file paths
from datetime import datetime
import time
import paho.mqtt.subscribe as sub
import scans_to_db


def parser_process_wrapper():
    try:
        scans_to_db.process_daily_scans()
    # except ValueError as e:
    #     gv.logging.error("Error occurred in process_daily_scans: %s", e)
    except Exception as e:
        gv.logging.exception("ERROR in parser: ")

def scan_listener_wrapper():
    try:
        sub.callback(mqtt_subscribe_callback.on_scan, "tokenStations/+/onScan", hostname= broker_address)
    except Exception as e:
        gv.logging.exception("ERROR in Scan Listener: ")

gv.logging.info("Starting Backend...")

gv.logging.info("Recording broker trafic subscribed to: tokenStations/+/onScan") # "+" is a wildcard
if __name__ == '__main__':
    broker_address = "172.25.2.56"  #set the Broker address
    # listen for scans in the exhibition process
    #scan_listener_process = Process(target=sub.callback, args=(mqtt_subscribe_callback.on_scan, "tokenStations/+/onScan"), kwargs={"hostname": broker_address})
    scan_listener_process = Process(target=scan_listener_wrapper, args=())

    
    # process for stores daily scans to database at the end of each day
    parse_daily_scans = Process(target=parser_process_wrapper, args=())

    #start the listener
    scan_listener_process.start()

    # start the db parser
    parse_daily_scans.start()
    