#import mqtt_subscribe_callback #contains callback functions for sub.callback
#import global_variables #contains all global variables and file paths
from datetime import datetime
import time
#import paho.mqtt.subscribe as sub

print("Starting Backend...")
now = datetime.now().time()
currentDateTime = str(now.strftime("[%d.%b.%Y:%H:%M:%S"))
print(currentDateTime)

#enter infinate loop
# while True:
#     # get current datetime and time
#     now = datetime.now().time()
#     currentDateTime = str(now.strftime("[%d.%b.%Y:%H:%M:%S"))
#     currentDate = str(now.strftime("%d.%b.%Y"))
#     stop_time = global_variables.checkEndTimes()

#     # if time conditions are met, start recording daily scan traffic...time constants are set in global variables
#     if now > global_variables.sub_start_time and now < stop_time:
#         print("Recording broker trafic subscribed to: tokenStations/+/onScan") # "+" is a wildcard
#         if __name__ == '__main__':
#             broker_address = "172.25.2.56"  #set the Broker address
#             sub.callback(mqtt_subscribe_callback.on_msg_print, "tokenStations/+/onScan", hostname=broker_address) #functions subscribes on Mqtt Broker and calls callback function "on_msg_print" from mqtt_callback

#     print(str(now) + "Main loop ended...")
#     print(" : Not yet the right time...waiting some more...")
#     print("Start Time is set to :  " + str(global_variables.sub_start_time))
#     print("Stop time is set to:   " + str(stop_time))
#     time.sleep(60)



