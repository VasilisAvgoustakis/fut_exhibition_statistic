from datetime import datetime

#####variables regarding reading and graphing video plays
assetLog_path_textfile = open("logs/assetLog_database_path.txt", "r")# open text file containing  assetLog Database file path as string
assetLog_path_string = assetLog_path_textfile.readline()#read the the first line of the file containing the path as string
assetDatabase = "./"+ str(assetLog_path_string) #set file path
htmlTotalBar = "./total_video_interactions_bar.html"
htmlTotalPie = "./total_video_interactions_pie.html"



######variables regarding token scan
tokenLog_path_textfile = open("txt/tokenLog_database_path.txt", "r")# open text file containing  assetLog Database file path as string
questions_path_textfile = open("txt/questions_database_path.txt", "r")
tokenLog_path_string = tokenLog_path_textfile.readline()#read the the first line of the file containing the path as string
questions_path_string = questions_path_textfile.readline()
tokenDatabase = "./" + str(tokenLog_path_string) #set file path
questionsDatabase = "./" + str(questions_path_string)

###variables regarding time, visitors and paths
timeperRegion_Database = "database/reagiontimeDatabase.csv"
tokenStation_coordinates = "txt/tokenmap_coordinates.csv"
total_armbaender = "database/totalArmbaender.csv"

#html file paths
#token_htmlTotalBar = "html/total_tokenScans_perStation_bar.html"
#token_htmlTotalPie = "html/total_tokenScans_perStation_pie.html"
#token_htmlAvgScansBar = "html/average_tokenScans_perStation_perMonth_bar.html"
#token_htmlAvgScansPie = "html/average_tokenScans_perStation_perMonth_pie.html"
#token_htmlTotalRegion ="html/token_scans_per_region.html"
#token_htmlPopularityRegion = "html/token_popularity_per_region.html"
#questions_totalScans ="html/questionsBar_Scans.html"
#region_average_times = "html/Region_Average_TimesperArmband.html"
#exhibition_visitors = "html/exhibition_visitors_per_day.html"
#exhibitions_paths = "html/exhibition_paths.html"

#html paths for ubuntu server
token_htmlTotalBar = "/var/www/html/total_tokenScans_perStation_bar.html"
token_htmlTotalPie = "/var/www/html/total_tokenScans_perStation_pie.html"
token_htmlAvgScansBar = "/var/www/html/average_tokenScans_perStation_perMonth_bar.html"
token_htmlAvgScansPie = "/var/www/html/average_tokenScans_perStation_perMonth_pie.html"
token_htmlTotalRegion ="/var/www/html/token_scans_per_region.html"
token_htmlPopularityRegion = "/var/www/html/token_popularity_per_region.html"
questions_totalScans ="/var/www/html/questionsBar_Scans.html"
region_average_times = "/var/www/html/Region_Average_TimesperArmband.html"
exhibition_visitors = "/var/www/html/exhibition_visitors_per_day.html"
exhibitions_paths = "/var/www/html/exhibition_paths.html"


#log files
daily_scans_log = "logs/token_daily_log.txt"
log_archive = "logs/token_archive_log.txt"



######Time System
sub_start_time = datetime.strptime("10:00:00", "%H:%M:%S").time()

def checkEndTimes():
    #read_graph_start_time = datetime.strptime("19:29:00", "%H:%M:%S").time() # count asset recalls from this time onward ...set later at 20:00
    day = datetime.today().weekday()
    now = datetime.now().time()

    if day == 3 :
        print("Thursday")

        sub_stop_time = datetime.strptime("19:35:00", "%H:%M:%S").time() # count asset recalls from this time onward ...set later at 19:59

    elif day == 1:
        print("Schließtag")
        sub_stop_time = datetime.strptime("09:00:00", "%H:%M:%S").time()# set that back to 9:00

    else:
        print("Regular day")
        sub_stop_time = datetime.strptime("17:35:00", "%H:%M:%S").time()

    return sub_stop_time