from multiprocessing import Process
import mqtt_subscribe_callback #contains callback functions for sub.callback
import global_variables as glv #contains all global variables and file paths
from datetime import datetime
import time
import paho.mqtt.subscribe as sub


glv.logging.info("Starting Backend...")

glv.logging.info("Recording broker trafic subscribed to: tokenStations/+/onScan") # "+" is a wildcard
if __name__ == '__main__':
    broker_address = "172.25.2.56"  #set the Broker address
    # listen for scans in the exhibition process
    scan_listener_process = Process(target=sub.callback, args=(mqtt_subscribe_callback.on_scan, "tokenStations/+/onScan"), kwargs={"hostname": broker_address})
    
    # define another process for storing daily scans to database at the end of each day


    # 
    
    #start the listener
    scan_listener_process.start()
    