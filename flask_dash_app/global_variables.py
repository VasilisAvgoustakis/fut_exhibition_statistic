from datetime import datetime, date, timedelta
import logging
import os
from mysql.connector import pooling
from mysql.connector import Error
import pandas as pd


# Get the current date and time
current_datetime = datetime.now()

yesterday = date.today() - timedelta(days=1)

# var contains min and max default dates
start_date_string = '2020-09-23'
#end_date_string = yesterday.strftime('%Y-%m-%d')
#end_date_string = '2020-09-23'

# Format the date in the desired format
date_string = current_datetime.strftime("%Y-%m-%d")

# Append the formatted date to the log file name
log_file_name = f"./logs/app_log_{date_string}.txt"
####

# List containing tha categories of graphs that can be displayed by the app
graph_types = ['Gesamtscans pro Token-Station (ALLE)', 
               'Durchschnittliche Scans pro Token-Station (ALLE)',
                'Gesamtscans pro Bereich',
                'Durchschnittliche Scans pro Bereich per Station',
                'Durchschnittlche Zeit pro Besucher',
                'Anzahl der Besucher pro Tag',
                'Durchschnittliche Scans pro Besucher per Region',
                'Token Szenario pro Frage',
                'Wahrscheinlichste durchschnittliches Pfad',
                'Zufällige Pfade'
                ]

# graph information texts
query_total_scans_tk_msg = "Gesamtzahl der Scans pro Token-Station (alle Stationen)"
query_total_scans_tk_msg_pie = "Gesamtzahl der Scans pro Token-Station (Pide per Denkraum)"
avg_scans_pro_monat_msg = "Anzahl der Scans pro Token-Station im Durchschnitt pro Monat"
avg_scans_pro_monat_msg_pie = "Anzahl der Scans pro Token-Station im Durchschnitt pro Monat Per Bereich"
total_scans_per_region_msg = "Gesamtzahl der Scans pro Denkraum + die interaktiven Stationen"
avg_scans_per_region_per_station_msg = "Gesamtzahl der Scans per Denkraum durch die Anzahl der Token-Station im gleichen Denkraum (proportional) -> Anzahl der Scans in einer Denkraum im Durchschnitt pro Station"
avg_time_per_visitro_msg = "Die Durschnittszeit in Minuten die ein Besucher in den jeweiligen Denkräumen spendet."
total_visitors_per_day_msg = "Die Gesamtanzahl einzelne Armbänder pro Tag neben der Anzahl der Zukunfsmaschine Einwürfe"
avg_scans_per_visitor_msg = "Wie viele Scans macht der/die durchschnittliche Besucher*inn in jedem Denkraum und in der Gesamte Ausstellung?"
vote_scans_per_question_msg = "Anzahl der entsprechenden Antwort zu jeder Frage."
probable_path_msg = "Der Wahrscheinlichste bescuher Pfad anhand alle einzelnen Besucher Pfaden in der ausgewählte Zeitfenster!"
random_paths_msg = "Der Wahrscheinlichste bescuher Pfad anhand alle einzelnen Besucher Pfaden in der ausgewählte Zeitfenster!"


style_data_conditional=[
                        {
                            'if': {'row_index': 'odd'},
                            'backgroundColor': 'rgb(220, 220, 220)',
                        },
                        {
                            'if': {
                                'column_editable': False  # True | False
                            },
                            'cursor': 'not-allowed'
                        },
                        {
                            'if': {
                                'state': 'selected'  # 'active' | 'selected'
                            },
                            'backgroundColor': 'rgba(0, 0, 255, 0.5)'
                        },
                        # {
                        #     'if': {
                        #         'filter_query': '{Station} > 50',
                        #         'column_id': 'Station Name'
                        #     },
                        #     'backgroundColor': 'tomato',
                        #     'color': 'white'
                        # }
                    ]

# this global var stores the final df data as were plotted by the corresponding triggered graph
# to be optionally downloaded by the user as CSV
csv_file_data=pd.DataFrame()

# Create a dictionary to map station IDs from random paths data to their x and y coordinates
# so that they can be accessed as a global var from callbacks.py
coord_dict = {}


# basic loggin configuration
logging.basicConfig(
    level=logging.INFO,  # Set the desired log level (e.g., logging.INFO, logging.DEBUG)
    format='%(asctime)s [%(levelname)s] %(message)s',  # Set the log message format
    filename=log_file_name,  # Set the log file path
    filemode='a'  # Set the file mode: 'a' for append, 'w' for overwrite
)


