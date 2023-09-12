
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
    total_records,\
    from_date,\
    up_to_date,\
    TIMESTAMPDIFF(MONTH, from_date, up_to_date) AS elapsed_months,\
    archived,\
    total_records / TIMESTAMPDIFF(MONTH, from_date, up_to_date) AS average_records_per_month \
FROM ( \
        SELECT t.tk_station_id AS station, \
                    t.theme_area AS area, \
            COUNT(s.scan_id) AS total_records, \
                    CASE  \
                            WHEN t.installation_date >= '2020-09-24' -- place start date here \
                            THEN t.installation_date \
                            ELSE '2020-09-24' -- place start date here \
        END AS from_date,\
            CASE \
                WHEN t.decomissioned IS NOT NULL AND t.decomissioned <= '2023-09-04' -- end date here \
        THEN t.decomissioned \
                            WHEN t.decomissioned IS NOT NULL AND t.decomissioned >= '2023-09-04' -- end date here \
        THEN '2023-09-04' -- end date here \
                ELSE '2023-09-04' -- place end date here \
            END AS up_to_date, \
         \
                    t.decomissioned as archived \
         \
        FROM token_stations t \
        JOIN scans s ON t.tk_station_id = s.scan_station_id \
        WHERE t.tk_type != 'vote' \
        AND t.tk_type != 'interactive' \
        AND t.theme_area != 'gallery' \
        AND s.scan_date >= '2020-09-24' -- start date \
        AND s.scan_date <= '2023-09-04' -- end date \
        GROUP BY t.tk_station_id \
         \
        UNION\
         \
        SELECT t.tk_station_id AS station, t.tk_type AS area, \
            COUNT(s.scan_id) AS total_records, \
            CASE \
                            WHEN t.installation_date >= '2020-09-24' -- place start date here \
                            THEN t.installation_date \
                            ELSE '2020-09-24' -- place start date here \
        END AS from_date,\
            CASE \
                WHEN t.decomissioned IS NOT NULL AND t.decomissioned <= '2023-09-04' -- end date here \
        THEN t.decomissioned\
                            WHEN t.decomissioned IS NOT NULL AND t.decomissioned >= '2023-09-04' -- end date here \
        THEN '2023-09-04' -- end date here \
                ELSE '2023-09-04' -- place end date here \
            END AS up_to_date, \
            t.decomissioned as archived \
            \
        FROM token_stations t \
        JOIN scans s ON t.tk_station_id = s.scan_station_id \
        WHERE t.tk_type != 'vote' \
        AND t.tk_type = 'interactive' \
        AND s.scan_date >= '2020-09-24' -- start date \
        AND s.scan_date <= '2023-09-04' -- end date \
         \
        GROUP BY t.tk_station_id  \
        ORDER BY area, `from_date` DESC \
            \
)AS subquery \
ORDER BY area, from_date DESC;"


queries = [query_total_scans_tk, avg_scans_pro_monat]
