from datetime import datetime
import time
import global_variables as gv
import read_token_data
import graph_data
import graph_time
from multiprocessing import Process



# callback function of mqtt sub listener
def on_scan(client, stop, message):

    # get current datetime and time
    now = datetime.now()
    currentTime = now.time()
    stop_time = gv.checkEndTimes()

    #call stop_on_msg_print function to check time and if recording must be paused, put the returned boolean in a variable
    #stop = stop_on_msg_print()
    daily_report = open("logs/token_daily_log.txt", "a")
    report_archive = open("logs/token_archive_log.txt", "a")

    if currentTime < stop_time:
        # get current time and date
        formated_date_time = now.strftime("%d.%m.%Y_%H:%M:%S")
        
        # write the token scan messages to daily_report file and archive file
        daily_report.write(formated_date_time + "__" + ("%s %s" % (message.topic, message.payload)) + "\n")
        report_archive.write(formated_date_time + "__" + ("%s %s" % (message.topic, message.payload)) + "\n")  # just for debugging and checking if stats are being counted correctly
        daily_report.close()
        report_archive.close()

    else: # log info
        gv.logging.info("Scan in invalid Timewindow occured!")



    #if stop is True:
        #gv.daily_report.close()# close the daily_report file containing all scan logs for the day
        #gv.report_archive.close()
        #time.sleep(5)# wait 5 sec

        # # call functions to read the updated databases for token scans and question scans
        # print("Reading daily data..")
        # p1 = Process(target=read_token_data.readTokenData, args=(gv.tokenDatabase,))
        # p2 = Process(target=read_token_data.readQuestionsData, args=(gv.questionsDatabase,))
        # p1.start()
        # p2.start()
        # p1.join()
        # p2.join()
        # p1.terminate()
        # p2.terminate()
        # #read_token_data.readTokenData(gv.tokenDatabase)
        # #read_token_data.readQuestionsData(gv.questionsDatabase)

        # #call graphing funtions to graph the updated databases and rewrite the corresponding html files
        # print("Graphing...")
        # p3 = Process(target=graph_data.graphTokenScans, args=(gv.tokenDatabase,))
        # p4 = Process(target=graph_data.graphTokenQuestions, args=(gv.questionsDatabase,))
        # p5 = Process(target=graph_time.graph_time_path_visits, args=(gv.timeperRegion_Database, gv.tokenStation_coordinates,
        #                                                              gv.daily_scans_log, gv.total_armbaender))
        # p3.start()
        # p4.start()
        # p5.start()
        # p3.join()
        # p4.join()
        # p5.join()
        # p3.terminate()
        # p4.terminate()
        # p5.terminate()

        # daily_report.truncate(0)

        #trap code in loop until its time to start the recording again
        # while True:
        #     stop_time = gv.checkEndTimes()
        #     now = datetime.now().time()#get current time
        #     gv.logging.info("in mqtt Waiting for the right time to record token scans again...")
        #     time.sleep(60)# wait 60 sec

        #     #if time is between recording start time > current time > recording stop time then break the waiting loop and let the recording record again
        #     if now > gv.sub_start_time and now < stop_time:
        #         break
        #     else:
        #         print(str(now) + " : Not yet the right time...waiting some more...")
        #         print("Start Time is set to :  "+ str(gv.sub_start_time))
        #         print("Stop time is set to:   " + str(stop_time))
        #         continue
