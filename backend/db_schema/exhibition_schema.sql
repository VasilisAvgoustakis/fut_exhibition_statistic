-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: mysql-db
-- Erstellungszeit: 03. Jul 2025 um 15:15
-- Server-Version: 8.0.35
-- PHP-Version: 8.2.8

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Datenbank: `futurium_exhibition_stats`
--

DELIMITER $$
--
-- Prozeduren
--
CREATE DEFINER=`root`@`%` PROCEDURE `calculate_given_date` ()   BEGIN

    -- Variables
    DECLARE total_armbands INT DEFAULT 0;
    DECLARE prev_band_code VARCHAR(50);
    DECLARE curr_band_code VARCHAR(50);
    DECLARE prev_scan_time TIME;
    DECLARE curr_scan_time TIME;
    DECLARE prev_area VARCHAR(50);
    DECLARE curr_area VARCHAR(50);
    DECLARE time_diff TIME;
    DECLARE total_technology TIME DEFAULT '00:00:00';
    DECLARE total_human TIME DEFAULT '00:00:00';
    DECLARE total_nature TIME DEFAULT '00:00:00';
    DECLARE total_interactive TIME DEFAULT '00:00:00';
    DECLARE curr_code_technology TIME DEFAULT '00:00:00';
    DECLARE curr_code_human TIME DEFAULT '00:00:00';
    DECLARE curr_code_nature TIME DEFAULT '00:00:00';
    DECLARE curr_code_interactive TIME DEFAULT '00:00:00';
    DECLARE cur2_done TINYINT DEFAULT 0;
 
	-- this cursor will always fetch the 1st record of the pair of times currently calculated
    DECLARE prev_cursor CURSOR FOR
        SELECT scan_band_code, scan_time, theme_area
        FROM t_occurences_perCode;

	-- this cursor will always fetch the 2nd record of the pair of times currently calculated
    DECLARE curr_cursor CURSOR FOR
        SELECT scan_band_code, scan_time, theme_area
        FROM t_second_to_last;
        

	
    -- temp table containing all scans of current day
    CREATE TEMPORARY TABLE todays_scans
    AS
    SELECT * FROM `scans` WHERE scan_date = '2022-02-03' ORDER BY scan_id;

    -- temp table containing all distinct todays armband codes from todays_scans
    CREATE TEMPORARY TABLE todays_codes 
    AS
    SELECT DISTINCT scan_band_code FROM todays_scans;
    
	-- count the total distinct armbands for today
	SELECT COUNT(*) INTO total_armbands FROM todays_codes;
    
    -- table containning scan_times and corresponding regions for each distinct code from  todays_codes.
    CREATE TEMPORARY TABLE t_occurences_perCode
    AS
    SELECT todays_scans.scan_band_code AS scan_band_code, todays_scans.scan_time AS scan_time, IF(token_stations.tk_type !=       'interactive', token_stations.theme_area, token_stations.tk_type) AS theme_area 
    FROM 
	todays_scans
    JOIN
	token_stations ON tk_station_id = scan_station_id
    JOIN
	todays_codes ON todays_scans.scan_band_code = todays_codes.scan_band_code
    ORDER BY   todays_codes.scan_band_code, todays_scans.scan_time;
		

	CREATE TEMPORARY TABLE t_second_to_last
	AS
	SELECT *
	FROM t_occurences_perCode
	LIMIT 1, 10000000000;
		

    OPEN prev_cursor;
    OPEN curr_cursor;
    
    
    read_loop: LOOP
    	FETCH prev_cursor INTO prev_band_code, prev_scan_time, prev_area;
        
        
        BEGIN      
   			-- a handler that deals with one or more conditions.
			-- CONTINUE: Execution of the current program continues.
			-- NOT FOUND: control what happens when a cursor reaches the end of a data set.
        	DECLARE CONTINUE HANDLER FOR NOT FOUND
			SET cur2_done = TRUE;
            FETCH curr_cursor INTO curr_band_code, curr_scan_time, curr_area;
        END;

    
    	IF cur2_done THEN -- if one of the cursors (1st the curr_cursor) reaches the end of its dataset

            
                
                -- we add the final total times calculated for the last armband code to the total times of the day
				SET total_technology = ADDTIME(total_technology, curr_code_technology);
            	SET total_human = ADDTIME(total_human, curr_code_human);
            	SET total_nature = ADDTIME(total_nature, curr_code_nature);
            	SET total_interactive = ADDTIME(total_interactive, curr_code_interactive);
                
                -- Scuffolding for testing
        		-- SELECT total_technology AS tech_t, total_human AS human_t, total_nature AS natur_t, total_interactive as inter_t;
        
        	-- insert the calculated total time into region_times
			INSERT INTO region_times (date, technology, human, nature, interactive)
            -- the values are the average time per region in (number of hours (float = total_seconds_preRegion / 3600)) over the 		total_number of armbands per day 
			VALUES ('2022-02-03', ((TIME_TO_SEC(total_technology)/3600)/total_armbands), ((TIME_TO_SEC(total_human)/3600)/total_armbands), ((TIME_TO_SEC(total_nature)/3600)/total_armbands), ((TIME_TO_SEC(total_interactive)/3600)/total_armbands));
			
            -- then set the total times per region to 0
        	SET total_technology = '00:00:00';
        	SET total_human = '00:00:00';
        	SET total_nature = '00:00:00';
        	SET total_interactive = '00:00:00';
        	LEAVE read_loop;
            
             -- in case that prev code is not NULL and it is the same as curr code then we still are counting for one current armband code
        	ELSEIF prev_band_code = curr_band_code THEN 
            	-- scuffolding for testing
            	-- SELECT prev_band_code, prev_scan_time, prev_area  AS 'prev_cursor: prev=curr';
                -- SELECT curr_band_code, curr_scan_time, curr_area AS 'curr_cursor: prev=curr';
                
        		-- get the time difference
        		SET time_diff = TIMEDIFF(curr_scan_time, prev_scan_time);
            
            	-- add the time diff to the corresponding area variable for the current armband code
            	CASE	
                	WHEN prev_area = 'technology' THEN
                	SET curr_code_technology = ADDTIME(curr_code_technology, time_diff);
                	WHEN prev_area = 'human' THEN
                	SET curr_code_human = ADDTIME(curr_code_human, time_diff);
                	WHEN prev_area = 'nature' THEN
                	SET curr_code_nature = ADDTIME(curr_code_nature, time_diff);
                	WHEN prev_area = 'interactive' THEN
                	SET curr_code_interactive = ADDTIME(curr_code_interactive, time_diff);
                    ELSE
                    	SET curr_band_code = curr_band_code; -- No-op command
            	END CASE;
                
           
        	ELSEIF  prev_band_code != curr_band_code THEN
   
                
                -- add the last time diff to the corresponding area variable for the current armband code
            	CASE	
                	WHEN prev_area = 'technology' THEN
                	SET curr_code_technology = ADDTIME(curr_code_technology, time_diff);
                	WHEN prev_area = 'human' THEN
                	SET curr_code_human = ADDTIME(curr_code_human, time_diff);
                	WHEN prev_area = 'nature' THEN
                	SET curr_code_nature = ADDTIME(curr_code_nature, time_diff);
                	WHEN prev_area = 'interactive' THEN
                	SET curr_code_interactive = ADDTIME(curr_code_interactive, time_diff);
                    ELSE
                    	SET curr_band_code = curr_band_code; -- No-op command
            	END CASE;
                
                
				-- we add the the times calculated for the current armband code to the total times of the day
				SET total_technology = ADDTIME(total_technology, curr_code_technology);
            	SET total_human = ADDTIME(total_human, curr_code_human);
            	SET total_nature = ADDTIME(total_nature, curr_code_nature);
            	SET total_interactive = ADDTIME(total_interactive, curr_code_interactive);
            
            	-- then we reset the times for the current code
            	SET curr_code_technology = '00:00:00';
            	SET curr_code_human = '00:00:00';
            	SET curr_code_nature = '00:00:00';
            	SET curr_code_interactive = '00:00:00';
                
                -- scuffolding for testing
                -- SELECT curr_code_technology AS tech, curr_code_human AS human, curr_code_nature AS natur, curr_code_interactive as inter;
            	
        END IF;
    END LOOP;

    CLOSE prev_cursor;
    CLOSE curr_cursor;
    SELECT cur2_done;
END$$

CREATE DEFINER=`regular_user`@`%` PROCEDURE `calculate_region_times` ()   BEGIN

    -- Variables
    DECLARE total_armbands INT DEFAULT 0;
    DECLARE prev_band_code VARCHAR(50);
    DECLARE curr_band_code VARCHAR(50);
    DECLARE prev_scan_time TIME;
    DECLARE curr_scan_time TIME;
    DECLARE prev_area VARCHAR(50);
    DECLARE curr_area VARCHAR(50);
    DECLARE time_diff TIME;
    DECLARE total_technology TIME DEFAULT '00:00:00';
    DECLARE total_human TIME DEFAULT '00:00:00';
    DECLARE total_nature TIME DEFAULT '00:00:00';
    DECLARE total_interactive TIME DEFAULT '00:00:00';
    DECLARE curr_code_technology TIME DEFAULT '00:00:00';
    DECLARE curr_code_human TIME DEFAULT '00:00:00';
    DECLARE curr_code_nature TIME DEFAULT '00:00:00';
    DECLARE curr_code_interactive TIME DEFAULT '00:00:00';
    DECLARE cur2_done TINYINT DEFAULT 0;
 
	-- this cursor will always fetch the 1st record of the pair of times currently calculated
    DECLARE prev_cursor CURSOR FOR
        SELECT scan_band_code, scan_time, theme_area
        FROM t_occurences_perCode;

	-- this cursor will always fetch the 2nd record of the pair of times currently calculated
    DECLARE curr_cursor CURSOR FOR
        SELECT scan_band_code, scan_time, theme_area
        FROM t_second_to_last;
        

	
    -- temp table containing all scans of current day
    CREATE TEMPORARY TABLE todays_scans
    AS
    SELECT * FROM `scans` WHERE scan_date = CURDATE() ORDER BY scan_id;

    -- temp table containing all distinct todays armband codes from todays_scans
    CREATE TEMPORARY TABLE todays_codes 
    AS
    SELECT DISTINCT scan_band_code FROM todays_scans;
    
	-- count the total distinct armbands for today
	SELECT COUNT(*) INTO total_armbands FROM todays_codes;
    
    -- table containning scan_times and corresponding regions for each distinct code from  todays_codes.
    CREATE TEMPORARY TABLE t_occurences_perCode
    AS
    SELECT todays_scans.scan_band_code AS scan_band_code, todays_scans.scan_time AS scan_time, IF(token_stations.tk_type !=       'interactive', token_stations.theme_area, token_stations.tk_type) AS theme_area 
    FROM 
	todays_scans
    JOIN
	token_stations ON tk_station_id = scan_station_id
    JOIN
	todays_codes ON todays_scans.scan_band_code = todays_codes.scan_band_code
    ORDER BY   todays_codes.scan_band_code, todays_scans.scan_time;
		

	CREATE TEMPORARY TABLE t_second_to_last
	AS
	SELECT *
	FROM t_occurences_perCode
	LIMIT 1, 10000000000;
		

    OPEN prev_cursor;
    OPEN curr_cursor;
    
    
    read_loop: LOOP
    	FETCH prev_cursor INTO prev_band_code, prev_scan_time, prev_area;
        
        
        BEGIN      
   			-- a handler that deals with one or more conditions.
			-- CONTINUE: Execution of the current program continues.
			-- NOT FOUND: control what happens when a cursor reaches the end of a data set.
        	DECLARE CONTINUE HANDLER FOR NOT FOUND
			SET cur2_done = TRUE;
            FETCH curr_cursor INTO curr_band_code, curr_scan_time, curr_area;
        END;

    
    	IF cur2_done THEN -- if one of the cursors (1st the curr_cursor) reaches the end of its dataset

            
                
                -- we add the final total times calculated for the last armband code to the total times of the day
				SET total_technology = ADDTIME(total_technology, curr_code_technology);
            	SET total_human = ADDTIME(total_human, curr_code_human);
            	SET total_nature = ADDTIME(total_nature, curr_code_nature);
            	SET total_interactive = ADDTIME(total_interactive, curr_code_interactive);
                
                -- Scuffolding for testing
        		-- SELECT total_technology AS tech_t, total_human AS human_t, total_nature AS natur_t, total_interactive as inter_t;
        
        	-- insert the calculated total time into region_times
			INSERT INTO region_times (date, technology, human, nature, interactive)
            -- the values are the average time per region in (number of hours (float = total_seconds_preRegion / 3600)) over the 		total_number of armbands per day 
			VALUES (CURDATE(), ((TIME_TO_SEC(total_technology)/3600)/total_armbands), ((TIME_TO_SEC(total_human)/3600)/total_armbands), ((TIME_TO_SEC(total_nature)/3600)/total_armbands), ((TIME_TO_SEC(total_interactive)/3600)/total_armbands));
			
            -- then set the total times per region to 0
        	SET total_technology = '00:00:00';
        	SET total_human = '00:00:00';
        	SET total_nature = '00:00:00';
        	SET total_interactive = '00:00:00';
        	LEAVE read_loop;
            
             -- in case that prev code is not NULL and it is the same as curr code then we still are counting for one current armband code
        	ELSEIF prev_band_code = curr_band_code THEN 
            	-- scuffolding for testing
            	-- SELECT prev_band_code, prev_scan_time, prev_area  AS 'prev_cursor: prev=curr';
                -- SELECT curr_band_code, curr_scan_time, curr_area AS 'curr_cursor: prev=curr';
                
        		-- get the time difference
        		SET time_diff = TIMEDIFF(curr_scan_time, prev_scan_time);
            
            	-- add the time diff to the corresponding area variable for the current armband code
            	CASE	
                	WHEN prev_area = 'technology' THEN
                	SET curr_code_technology = ADDTIME(curr_code_technology, time_diff);
                	WHEN prev_area = 'human' THEN
                	SET curr_code_human = ADDTIME(curr_code_human, time_diff);
                	WHEN prev_area = 'nature' THEN
                	SET curr_code_nature = ADDTIME(curr_code_nature, time_diff);
                	WHEN prev_area = 'interactive' THEN
                	SET curr_code_interactive = ADDTIME(curr_code_interactive, time_diff);
                    ELSE
                    	SET curr_band_code = curr_band_code; -- No-op command
            	END CASE;
                
           
        	ELSEIF  prev_band_code != curr_band_code THEN
   
                
                -- add the last time diff to the corresponding area variable for the current armband code
            	CASE	
                	WHEN prev_area = 'technology' THEN
                	SET curr_code_technology = ADDTIME(curr_code_technology, time_diff);
                	WHEN prev_area = 'human' THEN
                	SET curr_code_human = ADDTIME(curr_code_human, time_diff);
                	WHEN prev_area = 'nature' THEN
                	SET curr_code_nature = ADDTIME(curr_code_nature, time_diff);
                	WHEN prev_area = 'interactive' THEN
                	SET curr_code_interactive = ADDTIME(curr_code_interactive, time_diff);
                    ELSE
                    	SET curr_band_code = curr_band_code; -- No-op command
            	END CASE;
                
                
				-- we add the the times calculated for the current armband code to the total times of the day
				SET total_technology = ADDTIME(total_technology, curr_code_technology);
            	SET total_human = ADDTIME(total_human, curr_code_human);
            	SET total_nature = ADDTIME(total_nature, curr_code_nature);
            	SET total_interactive = ADDTIME(total_interactive, curr_code_interactive);
            
            	-- then we reset the times for the current code
            	SET curr_code_technology = '00:00:00';
            	SET curr_code_human = '00:00:00';
            	SET curr_code_nature = '00:00:00';
            	SET curr_code_interactive = '00:00:00';
                
                -- scuffolding for testing
                -- SELECT curr_code_technology AS tech, curr_code_human AS human, curr_code_nature AS natur, curr_code_interactive as inter;
            	
        END IF;
    END LOOP;

    CLOSE prev_cursor;
    CLOSE curr_cursor;
    SELECT cur2_done;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `insert_token_stations` ()   BEGIN
    -- Temporary table to hold distinct ids and min dates
    CREATE TEMPORARY TABLE IF NOT EXISTS TempTokenStations (
        tk_station_id VARCHAR(30),
        installation_date DATE,
        last_scan_date DATE
    );

    -- Insert distinct ids and min/max dates into temporary table
    INSERT INTO TempTokenStations (tk_station_id, installation_date, last_scan_date)
    SELECT 
        scan_station_id, 
        MIN(scan_date) as min_date, 
        MAX(scan_date) as max_date
    FROM scans
    GROUP BY scan_station_id;

    -- Insert data from temporary table into token_stations, handling duplicates
    INSERT INTO token_stations (tk_station_id, installation_date, decomissioned)
    SELECT 
        tk_station_id, 
        installation_date,
        CASE 
            WHEN last_scan_date <= CURDATE() - INTERVAL 3 DAY THEN last_scan_date
            ELSE NULL
        END as decomissioned
    FROM TempTokenStations
    ON DUPLICATE KEY UPDATE
        installation_date = LEAST(token_stations.installation_date, TempTokenStations.installation_date),
        decomissioned = CASE 
            WHEN TempTokenStations.last_scan_date <= CURDATE() - INTERVAL 3 DAY THEN TempTokenStations.last_scan_date
            WHEN token_stations.decomissioned IS NULL THEN NULL
            ELSE NULL
        END;

    -- Drop the temporary table
    DROP TEMPORARY TABLE TempTokenStations;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `populate_region_times` ()   BEGIN

    -- Variables
    DECLARE total_armbands INT DEFAULT 0;
    DECLARE prev_band_code VARCHAR(50);
    DECLARE curr_band_code VARCHAR(50);
    DECLARE prev_scan_time TIME;
    DECLARE curr_scan_time TIME;
    DECLARE prev_area VARCHAR(50);
    DECLARE curr_area VARCHAR(50);
    DECLARE time_diff TIME;
    DECLARE total_technology TIME DEFAULT '00:00:00';
    DECLARE total_human TIME DEFAULT '00:00:00';
    DECLARE total_nature TIME DEFAULT '00:00:00';
    DECLARE total_interactive TIME DEFAULT '00:00:00';
    DECLARE curr_code_technology TIME DEFAULT '00:00:00';
    DECLARE curr_code_human TIME DEFAULT '00:00:00';
    DECLARE curr_code_nature TIME DEFAULT '00:00:00';
    DECLARE curr_code_interactive TIME DEFAULT '00:00:00';
    DECLARE cur2_done TINYINT DEFAULT 0;

    
    -- New variable for looping through dates
    DECLARE curr_date DATE;
    DECLARE done TINYINT DEFAULT 0;
    
    -- Cursor for all distinct scan dates
    DECLARE date_cursor CURSOR FOR
        SELECT DISTINCT scan_date
        FROM scans;
        
    	-- this cursor will always fetch the 1st record of the pair of times currently calculated
    DECLARE prev_cursor CURSOR FOR
        SELECT scan_band_code, scan_time, theme_area
        FROM t_occurences_perCode;

	-- this cursor will always fetch the 2nd record of the pair of times currently calculated
    DECLARE curr_cursor CURSOR FOR
        SELECT scan_band_code, scan_time, theme_area
        FROM t_second_to_last;
        
    

    -- Handler for when the date cursor runs out of rows
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    


    -- Open the date cursor
    OPEN date_cursor;
    
    

    -- Start looping through each distinct date
    date_loop: LOOP
    
    
        FETCH date_cursor INTO curr_date;
        IF done THEN
            CLOSE date_cursor;
            LEAVE date_loop;
        END IF;
     
     

        SET cur2_done = FALSE;
	
    -- Temp table containing all scans of current day
    CREATE TEMPORARY TABLE todays_scans
    AS
    SELECT * FROM `scans` WHERE scan_date = curr_date ORDER BY scan_id;

    -- temp table containing all distinct todays armband codes from todays_scans
    CREATE TEMPORARY TABLE todays_codes 
    AS
    SELECT DISTINCT scan_band_code FROM todays_scans;
    
	-- count the total distinct armbands for today
	SELECT COUNT(*) INTO total_armbands FROM todays_codes;
    
    -- table containning scan_times and corresponding regions for each distinct code from  todays_codes.
    CREATE TEMPORARY TABLE t_occurences_perCode
    AS
    SELECT todays_scans.scan_band_code AS scan_band_code, todays_scans.scan_time AS scan_time,     IF(token_stations.tk_type != 'interactive', token_stations.theme_area,   token_stations.tk_type) AS theme_area 
    FROM 
	todays_scans
    JOIN
	token_stations ON tk_station_id = scan_station_id
    JOIN
	todays_codes ON todays_scans.scan_band_code = todays_codes.scan_band_code
    ORDER BY   todays_codes.scan_band_code, todays_scans.scan_time;
		
	CREATE TEMPORARY TABLE t_second_to_last
	AS
	SELECT *
	FROM t_occurences_perCode
	LIMIT 1, 10000000000;

		
	OPEN prev_cursor;
    OPEN curr_cursor;
    
    
    read_loop: LOOP
    
    
    FETCH prev_cursor INTO prev_band_code, prev_scan_time, prev_area;
        
        
    BEGIN      
   			-- a handler that deals with one or more conditions.
			-- CONTINUE: Execution of the current program continues.
			-- NOT FOUND: control what happens when a cursor reaches the end of a data set.
        	DECLARE CONTINUE HANDLER FOR NOT FOUND
			SET cur2_done = TRUE;
            FETCH curr_cursor INTO curr_band_code, curr_scan_time, curr_area;
        END;

    
    	IF cur2_done THEN -- if one of the cursors (1st the curr_cursor) reaches the end of its dataset
    
                -- we add the final total times calculated for the last armband code to the total times of the day
				SET total_technology = ADDTIME(total_technology, curr_code_technology);
            	SET total_human = ADDTIME(total_human, curr_code_human);
            	SET total_nature = ADDTIME(total_nature, curr_code_nature);
            	SET total_interactive = ADDTIME(total_interactive, curr_code_interactive);
                
                -- Scuffolding for testing
        		-- SELECT total_technology AS tech_t, total_human AS human_t, total_nature AS natur_t, total_interactive as inter_t;
        
        	-- insert the calculated total time into region_times
			INSERT INTO region_times (date, technology, human, nature, interactive)
            -- the values are the average time per region in (number of hours (float = total_seconds_preRegion / 3600)) over the 		total_number of armbands per day 
			VALUES (curr_date, ((TIME_TO_SEC(total_technology)/3600)/total_armbands), ((TIME_TO_SEC(total_human)/3600)/total_armbands), ((TIME_TO_SEC(total_nature)/3600)/total_armbands), ((TIME_TO_SEC(total_interactive)/3600)/total_armbands));
			
            -- then set the total times per region to 0
        	SET total_technology = '00:00:00';
        	SET total_human = '00:00:00';
        	SET total_nature = '00:00:00';
        	SET total_interactive = '00:00:00';
        	LEAVE read_loop;
            
             -- in case that prev code is not NULL and it is the same as curr code then we still are counting for one current armband code
        	ELSEIF prev_band_code = curr_band_code THEN 
            	-- scuffolding for testing
            	-- SELECT prev_band_code, prev_scan_time, prev_area  AS 'prev_cursor: prev=curr';
                -- SELECT curr_band_code, curr_scan_time, curr_area AS 'curr_cursor: prev=curr';
                
        		-- get the time difference
        		SET time_diff = TIMEDIFF(curr_scan_time, prev_scan_time);
            
            	-- add the time diff to the corresponding area variable for the current armband code
            	CASE	
                	WHEN prev_area = 'technology' THEN
                	SET curr_code_technology = ADDTIME(curr_code_technology, time_diff);
                	WHEN prev_area = 'human' THEN
                	SET curr_code_human = ADDTIME(curr_code_human, time_diff);
                	WHEN prev_area = 'nature' THEN
                	SET curr_code_nature = ADDTIME(curr_code_nature, time_diff);
                	WHEN prev_area = 'interactive' THEN
                	SET curr_code_interactive = ADDTIME(curr_code_interactive, time_diff);
					ELSE
                    SET curr_band_code = curr_band_code; -- No-op command            	
				END CASE;
                -- scuffolding for testing
                -- SELECT curr_code_technology AS tech, curr_code_human AS human, curr_code_nature AS natur, curr_code_interactive as inter;
            
             -- if the prev and curr armband codes are not the same it means we need to start counting times for the next armband code
        	ELSEIF  prev_band_code != curr_band_code THEN
            	-- scuffolding for testing
            	-- SELECT prev_band_code, prev_scan_time, prev_area  AS 'prev_cursor: prev!=curr';
                -- SELECT curr_band_code, curr_scan_time, curr_area AS 'curr_cursor: prev!=curr';
                -- SELECT curr_code_technology AS tech, curr_code_human AS human, curr_code_nature AS natur, curr_code_interactive as inter;
                
                -- add the last time diff to the corresponding area variable for the current armband code
            	CASE	
                	WHEN prev_area = 'technology' THEN
                	SET curr_code_technology = ADDTIME(curr_code_technology, time_diff);
                	WHEN prev_area = 'human' THEN
                	SET curr_code_human = ADDTIME(curr_code_human, time_diff);
                	WHEN prev_area = 'nature' THEN
                	SET curr_code_nature = ADDTIME(curr_code_nature, time_diff);
                	WHEN prev_area = 'interactive' THEN
                    SET curr_code_interactive = ADDTIME(curr_code_interactive, time_diff);
									ELSE
                    	SET curr_band_code = curr_band_code; -- No-op command
            	END CASE;
                
                
				-- we add the the times calculated for the current armband code to the total times of the day
				SET total_technology = ADDTIME(total_technology, curr_code_technology);
            	SET total_human = ADDTIME(total_human, curr_code_human);
            	SET total_nature = ADDTIME(total_nature, curr_code_nature);
            	SET total_interactive = ADDTIME(total_interactive, curr_code_interactive);
            
            	-- then we reset the times for the current code
            	SET curr_code_technology = '00:00:00';
            	SET curr_code_human = '00:00:00';
            	SET curr_code_nature = '00:00:00';
            	SET curr_code_interactive = '00:00:00';
                
                -- scuffolding for testing
                -- SELECT curr_code_technology AS tech, curr_code_human AS human, curr_code_nature AS natur, curr_code_interactive as inter;
            	
        		END IF;
                

    	
    END LOOP read_loop;
    
    CLOSE prev_cursor;
    CLOSE curr_cursor;
    
             -- Remember to close and destroy temporary tables and other resources used within the date loop
        DROP TEMPORARY TABLE IF EXISTS todays_scans;
        DROP TEMPORARY TABLE IF EXISTS todays_codes;
        DROP TEMPORARY TABLE IF EXISTS t_occurences_perCode;
        DROP TEMPORARY TABLE IF EXISTS t_second_to_last;
    
    

        

    END LOOP date_loop;
	CLOSE date_cursor;
   
	SELECT cur2_done;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `asset_calls`
--

CREATE TABLE `asset_calls` (
  `call_id` bigint UNSIGNED NOT NULL,
  `call_date` date NOT NULL,
  `call_time` time NOT NULL,
  `device_ip` varchar(15) NOT NULL,
  `device_name` varchar(20) NOT NULL,
  `area_name` enum('human','nature','technology','') NOT NULL,
  `media_id` varchar(25) NOT NULL,
  `asset_name` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Trigger `asset_calls`
--
DELIMITER $$
CREATE TRIGGER `insert_video_player` AFTER INSERT ON `asset_calls` FOR EACH ROW BEGIN
  INSERT IGNORE INTO video_players (device_ip, device_name, device_area, media_id)
  VALUES (NEW.device_ip, NEW.device_name, NEW.area_name, NEW.media_id);
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `region_times`
--

CREATE TABLE `region_times` (
  `date` date NOT NULL,
  `technology` float NOT NULL,
  `human` float NOT NULL,
  `nature` float NOT NULL,
  `interactive` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='stores the time in hours spend in each region by all users';

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `scans`
--

CREATE TABLE `scans` (
  `scan_id` bigint UNSIGNED NOT NULL,
  `scan_date` date NOT NULL,
  `scan_time` time NOT NULL,
  `scan_station_id` varchar(32) NOT NULL,
  `scan_band_code` varchar(24) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `token_stations`
--

CREATE TABLE `token_stations` (
  `token_db_id` int NOT NULL,
  `tk_station_id` varchar(32) NOT NULL,
  `name_text` varchar(50) DEFAULT NULL,
  `installation_date` date DEFAULT NULL,
  `theme_area` enum('human','technology','nature','gallery') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `tk_type` enum('normal','vote','interactive') DEFAULT NULL,
  `decomissioned` date DEFAULT NULL,
  `x_coord` float DEFAULT NULL,
  `y_coord` float DEFAULT NULL,
  `month_offset` int DEFAULT ((case when (`installation_date` < _utf8mb4'2021-05-21') then 6 else 0 end))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `video_players`
--

CREATE TABLE `video_players` (
  `device_id` int UNSIGNED NOT NULL,
  `device_ip` varchar(15) NOT NULL,
  `device_name` varchar(25) NOT NULL,
  `device_area` enum('human','nature','technology','') NOT NULL,
  `media_id` varchar(25) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Indizes der exportierten Tabellen
--

--
-- Indizes für die Tabelle `asset_calls`
--
ALTER TABLE `asset_calls`
  ADD PRIMARY KEY (`call_id`),
  ADD UNIQUE KEY `unique_index_per_minute` (`call_date`,`call_time`,`device_ip`);

--
-- Indizes für die Tabelle `region_times`
--
ALTER TABLE `region_times`
  ADD PRIMARY KEY (`date`);

--
-- Indizes für die Tabelle `scans`
--
ALTER TABLE `scans`
  ADD PRIMARY KEY (`scan_id`),
  ADD UNIQUE KEY `scan_UNIQUE_combi` (`scan_date`,`scan_station_id`,`scan_band_code`) COMMENT 'Through this index multiple scan of one band code to one station within the same day are disallowed (i.e. children at play) ',
  ADD UNIQUE KEY `scan_id_UNIQUE` (`scan_id`);

--
-- Indizes für die Tabelle `token_stations`
--
ALTER TABLE `token_stations`
  ADD PRIMARY KEY (`token_db_id`),
  ADD UNIQUE KEY `token_db_id_UNIQUE` (`token_db_id`),
  ADD UNIQUE KEY `tk_station_id_UNIQUE` (`tk_station_id`);

--
-- Indizes für die Tabelle `video_players`
--
ALTER TABLE `video_players`
  ADD PRIMARY KEY (`device_id`);

--
-- AUTO_INCREMENT für exportierte Tabellen
--

--
-- AUTO_INCREMENT für Tabelle `asset_calls`
--
ALTER TABLE `asset_calls`
  MODIFY `call_id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `scans`
--
ALTER TABLE `scans`
  MODIFY `scan_id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `token_stations`
--
ALTER TABLE `token_stations`
  MODIFY `token_db_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `video_players`
--
ALTER TABLE `video_players`
  MODIFY `device_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

DELIMITER $$
--
-- Ereignisse
--
CREATE DEFINER=`root`@`%` EVENT `update_token_stations_table` ON SCHEDULE EVERY 1 WEEK STARTS '2020-09-23 22:00:00' ON COMPLETION NOT PRESERVE ENABLE DO CALL insert_token_stations()$$

CREATE DEFINER=`root`@`%` EVENT `process_daily_times` ON SCHEDULE EVERY 1 DAY STARTS '2023-11-08 21:00:00' ON COMPLETION NOT PRESERVE ENABLE DO CALL calculate_region_times()$$

DELIMITER ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
