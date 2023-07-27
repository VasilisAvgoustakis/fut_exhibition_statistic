
import global_variables as gv

query_total_scans_tk = "SELECT t.tk_station_id as station, t.theme_area as area, COUNT(s.scan_id) AS Total_scans, t.decomissioned AS archived FROM token_stations t \
            JOIN scans s ON t.tk_station_id = s.scan_station_id WHERE t.tk_type != 'vote' \
            AND t.tk_type != 'interactive' \
            AND t.theme_area != 'gallery' \
            AND s.scan_date >= %s \
            AND s.scan_date <=  %s \
            GROUP BY t.tk_station_id \
            UNION \
            SELECT t.tk_station_id as station, t.tk_type as area, COUNT(s.scan_id) AS Total_scans, t.decomissioned AS archived \
            FROM token_stations t \
            JOIN scans s ON t.tk_station_id = s.scan_station_id \
            WHERE t.tk_type = 'interactive' \
            AND s.scan_date >= %s \
            AND s.scan_date <=  %s \
            AND t.theme_area != 'gallery' \
            GROUP BY t.tk_station_id \
            ORDER BY area, station \
            ;"


queries = [query_total_scans_tk]
#sequences of date constellatons of different querries
date_strings_sequences = [(gv.start_date_string, gv.end_date_string, gv.start_date_string, gv.end_date_string)]