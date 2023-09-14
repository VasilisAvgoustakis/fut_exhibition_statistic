
import global_variables as gv

query_total_scans_tk = "SELECT \
    t.tk_station_id AS station, \
    t.theme_area AS area, \
    COUNT(s.scan_id) AS Total_scans, \
    t.decomissioned AS archived \
FROM \
    token_stations t \
JOIN \
    scans s ON t.tk_station_id = s.scan_station_id \
WHERE \
    t.tk_type NOT IN ('vote', 'interactive') \
    AND t.theme_area != 'gallery' \
    AND s.scan_date BETWEEN @startDate AND @endDate \
GROUP BY \
    t.tk_station_id \
\
UNION \
\
SELECT \
    t.tk_station_id AS station, \
    t.tk_type AS area, \
    COUNT(s.scan_id) AS Total_scans, \
    t.decomissioned AS archived \
FROM \
    token_stations t \
JOIN \
    scans s ON t.tk_station_id = s.scan_station_id \
WHERE \
    t.tk_type = 'interactive' \
    AND t.theme_area != 'gallery' \
    AND s.scan_date BETWEEN @startDate AND @endDate \
GROUP BY \
    t.tk_station_id \
\
ORDER BY \
    area, \
    station;"

avg_scans_pro_monat = "SELECT \
    station, \
    area, \
    total_records, \
    from_date, \
    up_to_date, \
    TIMESTAMPDIFF(MONTH, from_date, up_to_date) AS elapsed_months, \
    archived, \
    total_records / TIMESTAMPDIFF(MONTH, from_date, up_to_date) AS average_records_per_month \
FROM (SELECT t.tk_station_id AS station, \
                    t.theme_area AS area, \
            COUNT(s.scan_id) AS total_records, \
                    CASE \
                            WHEN t.installation_date >= @startDate \
                            THEN t.installation_date \
                            ELSE @startDate \
        END AS from_date, \
            CASE \
                WHEN t.decomissioned IS NOT NULL AND t.decomissioned <= @endDate \
        THEN t.decomissioned \
                WHEN t.decomissioned IS NOT NULL AND t.decomissioned >= @endDate \
        THEN @endDate \
                ELSE @endDate \
            END AS up_to_date, \
                    t.decomissioned as archived \
        FROM token_stations t \
        JOIN scans s ON t.tk_station_id = s.scan_station_id \
        WHERE t.tk_type != 'vote' \
        AND t.tk_type != 'interactive' \
        AND t.theme_area != 'gallery' \
        AND s.scan_date >= @startDate \
        AND s.scan_date <= @endDate \
        GROUP BY t.tk_station_id \
        UNION \
        SELECT t.tk_station_id AS station, t.tk_type AS area, \
            COUNT(s.scan_id) AS total_records, \
            CASE \
                WHEN t.installation_date >= @startDate \
                THEN t.installation_date \
                ELSE @startDate \
            END AS from_date,\
            CASE \
                WHEN t.decomissioned IS NOT NULL AND t.decomissioned <= @endDate \
                THEN t.decomissioned \
                WHEN t.decomissioned IS NOT NULL AND t.decomissioned >= @endDate \
                THEN @endDate \
                ELSE @endDate \
            END AS up_to_date, \
            t.decomissioned as archived \
        FROM token_stations t \
        JOIN scans s ON t.tk_station_id = s.scan_station_id \
        WHERE t.tk_type != 'vote' \
        AND t.tk_type = 'interactive' \
        AND s.scan_date >= @startDate \
        AND s.scan_date <= @endDate \
        GROUP BY t.tk_station_id \
) AS subquery \
ORDER BY area, from_date DESC \
;"



queries = [query_total_scans_tk, avg_scans_pro_monat]
