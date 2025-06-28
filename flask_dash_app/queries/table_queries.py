"""
SQL queries for table data in the Flask Dash application.
"""

# Query for token stations table
TOKEN_STATIONS_TABLE = """
SELECT * FROM token_stations ORDER BY theme_area, tk_station_id;
"""