"""
Default configuration values for the application.
These can be overridden by environment variables.
"""
import os
from datetime import datetime, date, timedelta
import pandas as pd

# Database configuration
DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "mysql-db"),
    "user": os.environ.get("DB_USER", "regular_user"),
    "port": os.environ.get("DB_PORT", "3306"),
    "password": os.environ.get("DB_PASSWORD", "regular_pass"),
    "database": os.environ.get("DB_DATABASE", "futurium_exhibition_stats")
}

# Redis configuration
REDIS_CONFIG = {
    "host": os.environ.get("REDIS_HOST", "redis"),
    "port": int(os.environ.get("REDIS_PORT", "6379")),
    "db": int(os.environ.get("REDIS_DB", "0"))
}

# MQTT configuration
MQTT_CONFIG = {
    "broker_address": os.environ.get("MQTT_BROKER_ADDRESS", "172.25.2.56"),
    "topic": os.environ.get("MQTT_TOPIC", "tokenStations/+/onScan")
}

# Time configuration
TIME_CONFIG = {
    "sub_start_time": os.environ.get("SUB_START_TIME", "10:00:00"),
    "regular_stop_time": os.environ.get("REGULAR_STOP_TIME", "18:00:00"),
    "thursday_stop_time": os.environ.get("THURSDAY_STOP_TIME", "20:00:00"),
    "closed_day_stop_time": os.environ.get("CLOSED_DAY_STOP_TIME", "09:00:00")
}

# File paths
FILE_PATHS = {
    "daily_scans_file": os.environ.get("DAILY_SCANS_FILE", "./network_traffic_archives/token_daily_log.txt"),
    "scans_archive_file": os.environ.get("SCANS_ARCHIVE_FILE", "./network_traffic_archives/token_archive_log.txt"),
    "daily_asset_log": os.environ.get("DAILY_ASSET_LOG", "./network_traffic_archives/access.log")
}

# Date ranges for statistics
STATS_DATE_RANGES = {
    "start_date": os.environ.get("STATS_START_DATE", "2020-09-23"),
    "end_date": os.environ.get("STATS_END_DATE", (date.today() - timedelta(days=1)).strftime('%Y-%m-%d'))
}

# Graph types
GRAPH_TYPES = [
    'Gesamtscans pro Token-Station (ALLE)', 
    'Durchschnittliche Scans pro Token-Station (ALLE)',
    'Gesamtscans pro Bereich',
    'Durchschnittliche Scans pro Bereich per Station',
    'Durchschnittlche Zeit pro Besucher',
    'Anzahl der Besucher pro Tag',
    'Durchschnittliche Scans pro Besucher per Region',
    'Scans per Besucher Quartal',
    'Token Szenario pro Frage',
    'Wahrscheinlichste durchschnittliches Pfad',
    'Zufällige Pfade'
]

# Graph information texts
GRAPH_INFO_TEXTS = {
    "query_total_scans_tk_msg": "Gesamtzahl der Scans pro Token-Station (alle Stationen)",
    "query_total_scans_tk_msg_pie": "Gesamtzahl der Scans pro Token-Station (Pide per Denkraum)",
    "avg_scans_pro_monat_msg": "Anzahl der Scans pro Token-Station im Durchschnitt pro Monat",
    "avg_scans_pro_monat_msg_pie": "Anzahl der Scans pro Token-Station im Durchschnitt pro Monat Per Bereich",
    "total_scans_per_region_msg": "Gesamtzahl der Scans pro Denkraum + die interaktiven Stationen",
    "avg_scans_per_region_per_station_msg": "Gesamtzahl der Scans per Denkraum durch die Anzahl der Token-Station im gleichen Denkraum (proportional) -> Anzahl der Scans in einer Denkraum im Durchschnitt pro Station",
    "avg_time_per_visitro_msg": "Die Durschnittszeit in Minuten die ein Besucher in den jeweiligen Denkräumen spendet.",
    "total_visitors_per_day_msg": "Die Gesamtanzahl einzelne Armbänder pro Tag neben der Anzahl der Zukunfsmaschine Einwürfe",
    "avg_scans_per_visitor_msg": "Wie viele Scans macht der/die durchschnittliche Besucher*inn in jedem Denkraum und in der Gesamte Ausstellung?",
    "scans_per_visitor_percentile": "Wie viele Scans hat jeder Quartal der Armbandnutzer*innen?",
    "vote_scans_per_question_msg": "Anzahl der entsprechenden Antwort zu jeder Frage.",
    "probable_path_msg": "Der Wahrscheinlichste bescuher Pfad anhand alle einzelnen Besucher Pfaden in der ausgewählte Zeitfenster!",
    "random_paths_msg": "Der Wahrscheinlichste bescuher Pfad anhand alle einzelnen Besucher Pfaden in der ausgewählte Zeitfenster!"
}

# Logging configuration
LOGGING_CONFIG = {
    "level": os.environ.get("LOGGING_LEVEL", "INFO"),
    "format": os.environ.get("LOGGING_FORMAT", "%(asctime)s [%(levelname)s] %(message)s"),
    "backend_log_file": f"./logs/backend_log_{datetime.now().strftime('%Y-%m-%d')}.txt",
    "app_log_file": f"./logs/app_log_{datetime.now().strftime('%Y-%m-%d')}.txt",
    "filemode": os.environ.get("LOGGING_FILEMODE", "a")
}

# Table styling
TABLE_STYLE_DATA_CONDITIONAL = [
    {
        'if': {'row_index': 'odd'},
        'backgroundColor': 'rgb(220, 220, 220)',
    },
    {
        'if': {
            'column_editable': False
        },
        'cursor': 'not-allowed'
    },
    {
        'if': {
            'state': 'selected'
        },
        'backgroundColor': 'rgba(0, 0, 255, 0.5)'
    }
]

# CSV Downloads
# this global var stores the final df data as were plotted by the corresponding triggered graph
# to be optionally downloaded by the user as CSV
CSV_FILE_DATA=pd.DataFrame()
COORD_DICT ={} # matching container for coordinates so all shared Dash state lives in one module.