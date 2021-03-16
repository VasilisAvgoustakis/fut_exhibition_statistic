from datetime import datetime
import time
import global_variables
import read_token_data
import graph_data
import graph_time
from multiprocessing import Process

#functions is called in the beginning of each loop in callback function: "on_msg_print" to check the time and pause broker recording
def stop_on_msg_print():
    stop_time = global_variables.checkEndTimes()
    now = datetime.now().time()#get  current time
    time.sleep(1)#wait a second
    if now > stop_time:#if the current time is passed the mqtt recording stop time
        print(str(now) + "_Pausing Mqtt recording")
        return True #when True is returned it pauses recording and triggers the code for reading daily data and graphing
    else:
        return False #if false is returned the recording is continued as time conditions are not met yet


# function thats is being called every time a message is recieved from mqtt broker sub.callback
def on_msg_print(client, stop, message):

    #call stop_on_msg_print function to check time and if recording must be paused, put the returned boolean in a variable
    stop = stop_on_msg_print()
    daily_report = open("logs/token_daily_log.txt", "a")
    report_archive = open("logs/token_archive_log.txt", "a")

    if stop is True:
        #global_variables.daily_report.close()# close the daily_report file containing all scan logs for the day
        #global_variables.report_archive.close()
        time.sleep(5)# wait 5 sec

        # call functions to read the updated databases for token scans and question scans
        print("Reading daily data..")
        p1 = Process(target=read_token_data.readTokenData, args=(global_variables.tokenDatabase,))
        p2 = Process(target=read_token_data.readQuestionsData, args=(global_variables.questionsDatabase,))
        p1.start()
        p2.start()
        p1.join()
        p2.join()
        p1.terminate()
        p2.terminate()
        #read_token_data.readTokenData(global_variables.tokenDatabase)
        #read_token_data.readQuestionsData(global_variables.questionsDatabase)

        #call graphing funtions to graph the updated databases and rewrite the corresponding html files
        print("Graphing...")
        p3 = Process(target=graph_data.graphTokenScans, args=(global_variables.tokenDatabase,))
        p4 = Process(target=graph_data.graphTokenQuestions, args=(global_variables.questionsDatabase,))
        p5 = Process(target=graph_time.graph_time_path_visits, args=(global_variables.timeperRegion_Database, global_variables.tokenStation_coordinates,
                                                                     global_variables.daily_scans_log, global_variables.total_armbaender))
        p3.start()
        p4.start()
        p5.start()
        p3.join()
        p4.join()
        p5.join()
        p3.terminate()
        p4.terminate()
        p5.terminate()

        daily_report.truncate(0)

        #trap code in loop until its time to start the recording again
        while True:
            stop_time = global_variables.checkEndTimes()
            now = datetime.now().time()#get current time
            print("Waiting for the right time to record token scans again...")
            time.sleep(60)# wait 60 sec

            #if time is between recording start time > current time > recording stop time then break the waiting loop and let the recording record again
            if now > global_variables.sub_start_time and now < stop_time:
                break
            else:
                print(str(now) + " : Not yet the right time...waiting some more...")
                print("Start Time is set to :  "+ str(global_variables.sub_start_time))
                print("Stop time is set to:   " + str(stop_time))
                continue
    else:
        #print("Mqtt Recording is running again...")
        # get current time and date
        now = datetime.now()
        curr_date_time = now.strftime("%d.%m.%Y_%H:%M:%S")
        #print(curr_date_time + "__" + ("%s %s" % (message.topic, message.payload)))
        # write the token scan messages to daily_report file

        daily_report.write(curr_date_time + "__" + ("%s %s" % (message.topic, message.payload)) + "\n")
        report_archive.write(curr_date_time + "__" + ("%s %s" % (message.topic, message.payload)) + "\n")  # just for debugging and checking if stats are being counted correctly
        daily_report.close()
        report_archive.close()

        print(curr_date_time + "__" + ("%s %s" % (message.topic, message.payload)))


