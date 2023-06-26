import pandas as pd
import plotly.express as px
import plotly.io as pio
import global_variables
from datetime import datetime, time, date, timedelta



#function creates graphs by reading the dataframe created from the access.log
def graphVideo(file):
    data = pd.read_csv(file) #reads csv file as data
    df = pd.DataFrame(data, index= None) # turns data in Pandas DataFrame Format
    totalColumn = str(df.columns[5])#put the name of the total asset counts in a variable as string

    sorted = df.sort_values(by=[totalColumn], ascending= False)# sorts Datadrame by decending total asset gets
    totalsBarFig =px.bar(sorted, x="Exponate", y=totalColumn)#creates bar graph for total assets
    totalsPieFig = px.pie(sorted,names="Exponate", values=totalColumn)# creates pie graph for total assets

    pio.write_html(totalsBarFig, file="totalBar_interactions.html", auto_open=False)#write graph to html file
    pio.write_html(totalsPieFig, file="totalPie_interactions.html", auto_open=False)#write graph to html file



#funtion creates graph by reading the dataframe from mqtt token scans report
def graphTokenScans(file):

    # graphing total scans per exhibit
    data = pd.read_csv(file)  # reads csv file as data
    df = pd.DataFrame(data, index=None)  # turns data in Pandas DataFrame Format
    sortColumn = str(df.columns[3])#puts the "Bereich" column of the dataframe in a variable as string
    totalsColumn = str(df.columns[5])#puts the total scans column of the dataframe in a variable as string
    #print(df)
    sorted = df.drop(df.index[38:]).sort_values(by=[sortColumn], ascending=False)  #sorts dataframe after "Bereich" and removes genetics
    #print(sorted)
    # create figures
    totalsBarFig = px.bar(sorted, x="TokenName", y=sorted.columns[5],
                          title="Total Scans per Token Station")  # creates a bar graph showing the total scans per token station
    totalsPieFig = px.pie(sorted, names="TokenName", values=sorted.columns[5],
                          title="Anteil: Total Scans per Token Station")  # creates a bar graph showing the total scans per station

    #calculate avg scans per Month and temp save it in new Dataframe then graph it. All derived from total scans Dataframe
    avgScansperMonth_df = pd.DataFrame(sorted, index=None)# new dataframe to temp save the avg scans per month per statio
    row = 0# row counter

    for date in sorted["From Data"]:
        recStart_date = datetime.strptime(date, "%d.%b.%Y").date()#get the start date for every station
        todays_date = datetime.today().date()# get todays date

        #calculate the time delta between todays date and start date of each station
        months_since_recStart = ((todays_date - recStart_date).total_seconds())/2592000 #seconds per 30 days

        avgScansperMonth_df.iat[row, 5] = float(avgScansperMonth_df.iat[row, 5]) / months_since_recStart#edit the right row on the new temp dataframe
        row += 1



    # create figures
    avgScansPerMonthBar_Fig = px.bar(avgScansperMonth_df, x="TokenName", y=avgScansperMonth_df.columns[5],title="Average Scans per Token Station per Month")
    avgScansPerMonthPie_Fig = px.pie(avgScansperMonth_df, names="TokenName", values=avgScansperMonth_df.columns[5], title="Anteil: Average Scans per Token Station per Month")
######################################################################################

    #graphing scans per exhbition region and popularity
    bereich_occurence_count_df = df.groupby("Bereich")[sortColumn].count()#counts how many token stations each "Bereich" has and creates a new Dataframe

    allebereiche = df.iloc[:,3]#a 1d dataframe containg the whole "Bereich" column of the original dataframe
    bereiche = list()#a list to contain all the different bereiche names just once
    popularity_values = list() # a list to contain the popularity values

    #append all different in bereiche list, just once per name occurence
    for bereich in allebereiche:
        if bereich not in bereiche:
            bereiche.append(bereich)

    bereicheDict = dict(zip(bereiche,[0 ,0 ,0, 0]))#create dict with all four bereiche as keys

    totalBereicheKeys = [(k) for k in bereicheDict] # create a list containing all 3 bereich names from the dict keys

    row = 0#just a row counter to help in the coming loop

    #gets the value of total scans per row in dataframe and adds it to the corresponding "bereich" key in bereicheDict
    for value in df.iloc[:, 5]:
        bereich = df.iat[row,3]
        if bereich in totalBereicheKeys:
            bereicheDict[bereich] += value
        row += 1
    row = 0#reset row counter

    values = list()#create a list to contain just the values of bereicheDict

    #append the values  if bereiheDict in the values list
    for i in totalBereicheKeys:
        values.append(bereicheDict[i])

    totalScans = df[totalsColumn].sum()
    totalTokenStations = bereich_occurence_count_df.sum()

    for i in bereicheDict.keys():
        if i in bereich_occurence_count_df:
                                # totalscans per bereich %              /       stations per bereicch %
            popularity_values.append((bereicheDict[i]/(totalScans/100))/(bereich_occurence_count_df.get(key= i)/(totalTokenStations/100)))


    dfData = {"Bereich" : pd.Series(totalBereicheKeys),
              "Total Scans" : pd.Series(values),
              "Popularity" : pd.Series(popularity_values)
    }
    bereichePieDataframe = pd.DataFrame(dfData)

    #create figures
    bereichePieFig = px.pie(bereichePieDataframe, names="Bereich", values=bereichePieDataframe.columns[1], title="Total Scans per Region")
    bereichPopularityPie = px.pie(bereichePieDataframe, names="Bereich", values=bereichePieDataframe.columns[2], title= "Region Popularity")

    #write html files(on server change path to "/var/www/html/filename"
    pio.write_html(totalsBarFig, file=str(global_variables.token_htmlTotalBar), auto_open=False)  # write graph to html file
    pio.write_html(totalsPieFig, file=str(global_variables.token_htmlTotalPie), auto_open=False)
    pio.write_html(avgScansPerMonthBar_Fig, file=str(global_variables.token_htmlAvgScansBar), auto_open=False)  # write graph to html file
    pio.write_html(avgScansPerMonthPie_Fig, file=str(global_variables.token_htmlAvgScansPie), auto_open=False)  # write graph to html file
    pio.write_html(bereichePieFig, file=str(global_variables.token_htmlTotalRegion), auto_open=False)  # write graph to html file
    pio.write_html(bereichPopularityPie, file=str(global_variables.token_htmlPopularityRegion), auto_open=False)  # write graph to html file

    #html1 = open(global_variables.token_htmlTotalBar, "w")
    #html1.write(pio.to_html(totalsBarFig))
    #html1.close()
    print("reached end of graphing Data...")
    # show figures
    #totalsBarFig.show()
    #totalsPieFig.show()
    #bereichePieFig.show()
    #bereichPopularityPie.show()
    #bereichePieFig.show()
    #bereichPopularityPie.show()


def graphTokenQuestions(file):
    # graphing total scans per exhibit
    data = pd.read_csv(file)  # reads csv file as data
    df = pd.DataFrame(data, index=None)  # turns data in Pandas DataFrame Format
    answerAcolumn = str(df.columns[5])
    answerBcolumn = str(df.columns[6])
    answerCcolumn = str(df.columns[7])


    questionsBarFig = px.bar(df,x= "Question Names", y=[answerAcolumn, answerBcolumn, answerCcolumn], title="Questions Scans")
    pio.write_html(questionsBarFig, file=str(global_variables.questions_totalScans), auto_open=False)
    print("Reached end of graphing Questions...")
    #questionsBarFig.show()

#call functions for edits and debugging
#graphVideo(file) #give database filename as parameter
#graphTokenScans(global_variables.tokenDatabase)
#graphTokenQuestions(questionsDatabase)Genaua bis dann vielebn VasilisSorry