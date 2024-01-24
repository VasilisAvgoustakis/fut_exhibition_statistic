
import global_variables as gv


# Graph Data Queries
query_total_scans_tk = "SELECT \
    t.tk_station_id AS station, \
    t.name_text AS name, \
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
    t.name_text AS name, \
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
    name, \
    area, \
    total_records, \
    from_date, \
    up_to_date, \
    TIMESTAMPDIFF(DAY, from_date, up_to_date)/ 30.4375 AS elapsed_months, \
    archived, \
    total_records / (TIMESTAMPDIFF(DAY, from_date, up_to_date)/30.4375) AS average_records_per_month \
FROM (SELECT t.tk_station_id AS station, \
                    t.name_text AS name, \
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
        SELECT t.tk_station_id AS station, \
                t.name_text AS name, \
                t.tk_type AS area, \
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
        AND t.theme_area != 'gallery' \
        AND s.scan_date >= @startDate \
        AND s.scan_date <= @endDate \
        GROUP BY t.tk_station_id \
) AS subquery \
ORDER BY area, from_date DESC \
;"

total_scans_per_region = "SELECT area, COUNT(station) AS station_number_per_area, \
SUM(Total_scans) AS total_scans FROM( \
SELECT \
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
UNION \
SELECT \
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
    AND t.theme_area = 'gallery' \
    AND s.scan_date BETWEEN @startDate AND @endDate \
GROUP BY \
    t.tk_station_id \
UNION \
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
ORDER BY \
    area, \
    station) AS subquery \
GROUP BY area; \
"

avg_scans_per_region_per_station = "SELECT area, COUNT(station) AS station_number_per_area, \
SUM(Total_scans) AS total_scans, SUM(Total_scans)/COUNT(station) AS average_per_station FROM( \
SELECT \
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
UNION \
SELECT \
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
    AND t.theme_area = 'gallery' \
    AND s.scan_date BETWEEN @startDate AND @endDate \
GROUP BY \
    t.tk_station_id \
UNION \
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
ORDER BY \
    area, \
    station) AS subquery \
GROUP BY area; \
"

avg_time_per_visitor = "SELECT ROUND((SUM(technology)/ COUNT(DISTINCT date))* 60,0) AS Technik, \
    ROUND((SUM(human)/ COUNT(DISTINCT date)) * 60, 0) AS Mensch, \
    ROUND((SUM(nature)/ COUNT(DISTINCT date)) * 60, 0) AS Natur, \
    ROUND((SUM(interactive)/ COUNT(DISTINCT date)) * 60,0) AS Interaktiv \
    FROM region_times \
    WHERE date BETWEEN @startDate AND @endDate \
    HAVING COUNT(DISTINCT date) > 0 \
    UNION \
    SELECT \
    (SELECT COUNT(tk_station_id) \
        FROM token_stations \
        WHERE theme_area = 'technology' \
        AND tk_type = 'normal') AS Technik, \
    (SELECT COUNT(tk_station_id) \
        FROM token_stations \
        WHERE theme_area = 'human' \
        AND tk_type = 'normal') AS Mensch, \
    (SELECT COUNT(tk_station_id) \
        FROM token_stations \
        WHERE theme_area = 'nature' \
        AND tk_type = 'normal') AS Natur, \
    (SELECT COUNT(tk_station_id) \
        FROM token_stations \
        WHERE tk_type = 'interactive') AS Interaktiv;"

total_visitors_per_day = "SELECT s.scan_date, \
    COUNT(DISTINCT s.scan_band_code) AS unique_scan_band_codes, \
    (SELECT COUNT(*) FROM scans s2 WHERE s2.scan_date = s.scan_date \
    AND s2.scan_station_id = 'gaTokenFutureMachine' \
    AND s2.scan_date BETWEEN @startDate AND @endDate \
    ) AS ZM_scans \
    FROM scans s \
    JOIN \
    token_stations ON scan_station_id = tk_station_id \
    WHERE s.scan_date BETWEEN @startDate AND @endDate \
    GROUP BY scan_date; \
    "

avg_scans_per_visitor = "SELECT area, \
		total_records AS total_scans, \
		total_Visitors_perRegion AS total_visitors, \
        (total_records / total_Visitors_perRegion) AS average_scans_perVisitor, \
        b.total_visitors_all_regions \
FROM ( \
		SELECT t.theme_area AS area, COUNT(s.scan_id) AS total_records \
            FROM token_stations t \
            JOIN scans s ON t.tk_station_id = s.scan_station_id \
            WHERE t.tk_type != 'interactive' \
            AND s.scan_date BETWEEN @startDate AND @endDate \
            GROUP BY t.theme_area \
            UNION \
        SELECT 'interactive' AS area, COUNT(s.scan_id) AS total_records \
            FROM token_stations t \
            JOIN scans s ON t.tk_station_id = s.scan_station_id \
            WHERE t.tk_type = 'interactive' \
            AND s.scan_date BETWEEN @startDate AND @endDate \
        ) AS total_scans_perRegion \
JOIN \
        (SELECT region, SUM(unique_scan_band_codes_perDay_perRegion) \
        AS total_Visitors_perRegion \
FROM ( \
        SELECT ts.theme_area as region, COUNT(DISTINCT s.scan_band_code) AS unique_scan_band_codes_perDay_perRegion \
        FROM scans s \
        JOIN \
        token_stations ts ON s.scan_station_id = ts.tk_station_id \
        WHERE \
    	ts.tk_type != 'interactive' \
    	AND s.scan_date BETWEEN @startDate AND @endDate \
        GROUP BY ts.theme_area, s.scan_date \
        ) AS total_visitors_table \
        GROUP BY region \
        UNION \
        SELECT region, SUM(unique_scan_band_codes_perDay_perRegion) \
        AS total_Visitors_perRegion \
        FROM ( \
        SELECT ts.tk_type as region, COUNT(DISTINCT s.scan_band_code) AS unique_scan_band_codes_perDay_perRegion \
        FROM scans s \
        JOIN \
        token_stations ts ON s.scan_station_id = ts.tk_station_id \
        WHERE \
    	ts.tk_type = 'interactive' \
    	AND s.scan_date BETWEEN @startDate AND @endDate \
        GROUP BY ts.theme_area, s.scan_date \
        ) AS total_visitors_table \
        GROUP BY region) AS total_visitors_perRegion \
ON area = region \
\
CROSS JOIN ( \
SELECT SUM(distinct_count) AS total_visitors_all_regions \
FROM ( \
    SELECT COUNT(DISTINCT scan_band_code) AS distinct_count \
    FROM scans \
    WHERE \
    scan_date BETWEEN @startDate AND @endDate \
    GROUP BY scan_date \
) AS Total_Visitors_All_Areas) b;"

vote_scans_per_question = " \
  SELECT \
    t.tk_station_id AS station, \
    t.name_text AS name, \
    COUNT(s.scan_id) AS Total_scans \
FROM \
    token_stations t \
JOIN \
    scans s ON t.tk_station_id = s.scan_station_id \
WHERE \
    t.tk_type = 'vote' \
		AND s.scan_date BETWEEN @startDate AND @endDate \
GROUP BY \
    t.tk_station_id \
ORDER BY \
    t.theme_area, \
    t.tk_station_id;"

visitor_paths = "SELECT scan_band_code, \
scan_station_id, name_text, scan_date, scan_time, x_coord, y_coord \
FROM scans s \
INNER JOIN token_stations st \
ON scan_station_id = tk_station_id \
WHERE scan_date BETWEEN @startDate AND @endDate \
AND (st.decomissioned >= @startDate \
OR st.decomissioned IS NULL) \
AND st.tk_type != 'vote' \
ORDER BY scan_date, scan_band_code, scan_time;"


queries = [query_total_scans_tk, 
           avg_scans_pro_monat, 
           total_scans_per_region, 
           avg_scans_per_region_per_station,
           avg_time_per_visitor,
           total_visitors_per_day,
           avg_scans_per_visitor,
           vote_scans_per_question,
           visitor_paths, # use the same query for both last graphs containing paths
           visitor_paths
           ]

# Token Stations Table Query
token_stations_table = "SELECT * FROM token_stations ORDER BY theme_area, tk_station_id;"