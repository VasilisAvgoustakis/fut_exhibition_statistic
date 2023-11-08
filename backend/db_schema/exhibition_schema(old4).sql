-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: mysql-db
-- Erstellungszeit: 12. Okt 2023 um 11:55
-- Server-Version: 8.0.33
-- PHP-Version: 8.1.17

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

--
-- Daten für Tabelle `token_stations`
--

INSERT INTO `token_stations` (`token_db_id`, `tk_station_id`, `name_text`, `installation_date`, `theme_area`, `tk_type`, `decomissioned`, `x_coord`, `y_coord`, `month_offset`) VALUES
(1, 'auTokenIntercity', NULL, '2021-11-25', 'technology', 'normal', NULL, NULL, NULL, 0),
(2, 'auTokenRadioFeature', NULL, '2021-11-24', 'technology', 'interactive', NULL, NULL, NULL, 0),
(3, 'auTokenTravelBox', NULL, '2021-11-24', 'technology', 'interactive', NULL, NULL, NULL, 0),
(4, 'auTokenVillage', NULL, '2021-11-25', 'technology', 'normal', NULL, NULL, NULL, 0),
(5, 'auTokenVoteA', NULL, '2021-11-25', 'technology', 'vote', NULL, NULL, NULL, 0),
(6, 'auTokenVoteB', NULL, '2021-11-25', 'technology', 'vote', NULL, NULL, NULL, 0),
(7, 'auTokenVoteC', NULL, '2021-11-25', 'technology', 'vote', NULL, NULL, NULL, 0),
(8, 'eeTokenNuclearEnergy', NULL, '2020-09-23', 'technology', 'normal', '2022-02-03', 768.327, 444.77, 6),
(9, 'eeTokenNuclearFusion', NULL, '2020-09-23', 'technology', 'normal', '2022-02-03', 802.981, 620.703, 6),
(10, 'eeTokenSolarSpace', NULL, '2020-09-23', 'technology', 'normal', '2022-02-03', 816.309, 532.737, 6),
(11, 'eeTokenVoteA', NULL, '2020-09-23', 'technology', 'vote', '2022-02-03', 720.347, 354.138, 6),
(12, 'eeTokenVoteB', NULL, '2020-09-23', 'technology', 'vote', '2022-02-03', 720.347, 354.138, 6),
(13, 'eeTokenVoteC', NULL, '2020-09-23', 'technology', 'vote', '2022-02-03', 720.347, 354.138, 6),
(14, 'enTokenPigDog', NULL, '2020-09-23', 'human', 'normal', NULL, 525.753, 1708.29, 6),
(15, 'enTokenSolutions', NULL, '2020-09-23', 'human', 'normal', NULL, 379.143, 1638.98, 6),
(16, 'enTokenStatusQuo', NULL, '2020-09-23', 'human', 'normal', NULL, 555.075, 1833.57, 6),
(17, 'enTokenVoteA', NULL, '2020-09-23', 'human', 'vote', NULL, 304.504, 1849.57, 6),
(18, 'enTokenVoteB', NULL, '2020-09-23', 'human', 'vote', NULL, 304.504, 1849.57, 6),
(19, 'enTokenVoteC', NULL, '2020-09-23', 'human', 'vote', NULL, 304.504, 1849.57, 6),
(20, 'gaTokenDelete', NULL, '2020-09-23', 'gallery', 'normal', NULL, NULL, NULL, 6),
(21, 'gaTokenFutureMachine', NULL, '2020-09-23', 'gallery', 'interactive', NULL, 1478.33, 1645.22, 6),
(22, 'gtTokenGenetics0', NULL, '2020-09-23', 'technology', 'interactive', NULL, 1285.46, 711.335, 6),
(23, 'gtTokenGenetics1', NULL, '2020-09-23', 'technology', 'interactive', NULL, 1194.83, 660.688, 6),
(24, 'gtTokenGenetics2', NULL, '2020-09-23', 'technology', 'interactive', NULL, 1256.14, 626.034, 6),
(25, 'gtTokenGenetics3', NULL, '2020-09-23', 'technology', 'interactive', NULL, 1314.79, 580.718, 6),
(26, 'gtTokenGenetics4', NULL, '2020-09-23', 'technology', 'interactive', NULL, 1373.43, 548.73, 6),
(27, 'gtTokenGeneticsDetails', NULL, '2020-09-23', 'technology', 'normal', NULL, 1376.1, 706.004, 6),
(28, 'gtTokenVoteA', NULL, '2020-09-23', 'technology', 'vote', NULL, 1509.38, 674.016, 6),
(29, 'gtTokenVoteB', NULL, '2020-09-23', 'technology', 'vote', NULL, 1509.38, 674.016, 6),
(30, 'gtTokenVoteC', NULL, '2020-09-23', 'technology', 'vote', NULL, 1509.38, 674.016, 6),
(31, 'klTokenMaterials', NULL, '2020-09-23', 'nature', 'normal', NULL, 1770.61, 1028.6, 6),
(32, 'klTokenProductionCircles', NULL, '2020-09-23', 'nature', 'normal', NULL, 1634.66, 855.28, 6),
(33, 'klTokenProducts', NULL, '2020-09-23', 'nature', 'normal', NULL, 1791.99, 889.934, 6),
(34, 'klTokenVoteA', NULL, '2020-09-23', 'nature', 'vote', NULL, 1911.89, 1028.4, 6),
(35, 'klTokenVoteB', NULL, '2020-09-23', 'nature', 'vote', NULL, 1911.89, 1028.4, 6),
(36, 'klTokenVoteC', NULL, '2020-09-23', 'nature', 'vote', NULL, 1911.89, 1028.4, 6),
(37, 'knTokenConstruction', NULL, '2020-09-23', 'nature', 'normal', NULL, 1954.54, 1830.91, 6),
(38, 'knTokenFarming', NULL, '2020-09-23', 'nature', 'normal', NULL, 1791.84, 1878.98, 6),
(39, 'knTokenGreenCity', NULL, '2020-09-23', 'nature', 'normal', '2022-02-03', 1610.67, 1868.23, 6),
(40, 'knTokenVoteA', NULL, '2020-09-23', 'nature', 'vote', NULL, 1767.95, 1668.3, 6),
(41, 'knTokenVoteB', NULL, '2020-09-23', 'nature', 'vote', NULL, 1767.95, 1668.3, 6),
(42, 'knTokenVoteC', NULL, '2020-09-23', 'nature', 'vote', NULL, 1767.95, 1668.3, 6),
(43, 'knTokenWaterInCities', NULL, '2020-09-23', 'nature', 'normal', NULL, 1701.3, 1777.59, 6),
(44, 'koTokenCity', NULL, '2020-09-23', 'human', 'normal', '2022-02-03', 213.872, 1135.17, 6),
(45, 'koTokenEconomy', NULL, '2020-09-23', 'human', 'normal', '2022-02-03', 139.234, 1225.81, 6),
(46, 'koTokenVoteA', NULL, '2020-09-23', 'human', 'vote', '2022-02-03', 280.52, 1239.13, 6),
(47, 'koTokenVoteB', NULL, '2020-09-23', 'human', 'vote', '2022-02-03', 280.52, 1239.13, 6),
(48, 'koTokenVoteC', NULL, '2020-09-23', 'human', 'vote', '2022-02-03', 280.52, 1239.13, 6),
(49, 'mmTokenBci', NULL, '2020-09-23', 'technology', 'normal', NULL, 1240.15, 506.08, 6),
(50, 'mmTokenCyborgs', NULL, '2020-09-23', 'technology', 'normal', NULL, 1165.51, 599.378, 6),
(51, 'mmTokenMediRobots', NULL, '2020-09-24', 'technology', 'normal', NULL, 1053.6, 399.454, 6),
(52, 'mmTokenVoteA', NULL, '2020-09-24', 'technology', 'vote', NULL, 1077.54, 300.825, 6),
(53, 'mmTokenVoteB', NULL, '2020-09-24', 'technology', 'vote', NULL, 1077.54, 300.825, 6),
(54, 'mmTokenVoteC', NULL, '2020-09-24', 'technology', 'vote', NULL, 1077.54, 300.825, 6),
(55, 'mmTokenWorkplace', NULL, '2020-09-23', 'technology', 'normal', NULL, 1053.45, 498.083, 6),
(56, 'neTokenEnergySystems', NULL, '2020-09-23', 'nature', 'normal', NULL, 1610.67, 1500.37, 6),
(57, 'neTokenVoteA', NULL, '2020-09-23', 'nature', 'vote', NULL, 1613.34, 1241.8, 6),
(58, 'neTokenVoteB', NULL, '2020-09-23', 'nature', 'vote', NULL, 1613.34, 1241.8, 6),
(59, 'neTokenVoteC', NULL, '2020-09-23', 'nature', 'vote', NULL, 1613.34, 1241.8, 6),
(60, 'nkTokenCarbon', NULL, '2020-09-23', 'technology', 'normal', NULL, 605.723, 690.01, 6),
(61, 'nkTokenClimateEngineering', NULL, '2020-09-23', 'technology', 'normal', '2022-02-03', 483.103, 666.019, 6),
(62, 'nkTokenCreations', NULL, '2020-09-23', 'technology', 'normal', NULL, 778.99, 679.347, 6),
(63, 'nkTokenEngineeredFood', NULL, '2020-09-23', 'technology', 'normal', '2022-02-03', 632.379, 626.034, 6),
(64, 'nkTokenGraphen', NULL, '2020-09-23', 'technology', 'normal', NULL, 749.668, 724.663, 6),
(65, 'nkTokenNanoRacer', NULL, '2020-09-23', 'technology', 'normal', NULL, 680.361, 703.338, 6),
(66, 'nkTokenVoteA', NULL, '2020-09-23', 'technology', 'vote', NULL, 747.002, 642.028, 6),
(67, 'nkTokenVoteB', NULL, '2020-09-23', 'technology', 'vote', NULL, 747.002, 642.028, 6),
(68, 'nkTokenVoteC', NULL, '2020-09-23', 'technology', 'vote', NULL, 747.002, 642.028, 6),
(69, 'nlTokenBioinspiration', NULL, '2020-09-23', 'nature', 'normal', '2022-02-03', 2098.49, 1180.49, 6),
(70, 'nlTokenInsects', NULL, '2020-09-23', 'nature', 'normal', '2022-02-03', 2186.45, 1289.78, 6),
(71, 'nlTokenNewMedicine', NULL, '2020-09-23', 'nature', 'normal', '2022-02-03', 2037.18, 1111.18, 6),
(72, 'nlTokenOrganisms', NULL, '2020-09-23', 'nature', 'normal', '2022-02-03', 2143.8, 1340.43, 6),
(73, 'nlTokenVoteA', NULL, '2020-09-23', 'nature', 'vote', '2022-02-03', 2181.12, 1436.39, 6),
(74, 'nlTokenVoteB', NULL, '2020-09-23', 'nature', 'vote', '2022-02-03', 2181.12, 1436.39, 6),
(75, 'nlTokenVoteC', NULL, '2020-09-23', 'nature', 'vote', '2022-02-03', 2181.12, 1436.39, 6),
(76, 'reTokenEnergy', NULL, '2020-09-23', 'technology', 'normal', NULL, 275.182, 1007.22, 6),
(77, 'reTokenProduction', NULL, '2020-09-23', 'technology', 'normal', NULL, 365.814, 777.976, 6),
(78, 'reTokenSupply', NULL, '2020-09-23', 'technology', 'normal', NULL, 373.811, 961.906, 6),
(79, 'reTokenVoteA', NULL, '2020-09-23', 'technology', 'vote', NULL, 280.41, 1079.22, 6),
(80, 'reTokenVoteB', NULL, '2020-09-23', 'technology', 'vote', NULL, 280.41, 1079.22, 6),
(81, 'reTokenVoteC', NULL, '2020-09-23', 'technology', 'vote', NULL, 280.41, 1079.22, 6),
(82, 'suTokenFutureShopping', NULL, '2020-09-23', 'technology', 'normal', NULL, 986.911, 482.089, 6),
(83, 'suTokenSmartDistricts', NULL, '2020-09-23', 'technology', 'normal', NULL, 861.625, 487.421, 6),
(84, 'suTokenVirtualProduction', NULL, '2020-09-23', 'technology', 'normal', NULL, 1005.57, 332.813, 6),
(85, 'suTokenVoteA', NULL, '2020-09-23', 'technology', 'vote', NULL, 1032.23, 268.837, 6),
(86, 'suTokenVoteB', NULL, '2020-09-23', 'technology', 'vote', NULL, 1032.23, 268.837, 6),
(87, 'suTokenVoteC', NULL, '2020-09-23', 'technology', 'vote', NULL, 1032.23, 268.837, 6),
(88, 'wbTokenGlobe', NULL, '2021-11-25', 'human', 'normal', NULL, NULL, NULL, 0),
(89, 'wbTokenVoteA', NULL, '2021-11-24', 'human', 'vote', NULL, NULL, NULL, 0),
(90, 'wbTokenVoteB', NULL, '2021-11-24', 'human', 'vote', NULL, NULL, NULL, 0),
(91, 'wbTokenVoteC', NULL, '2021-11-27', 'human', 'vote', NULL, NULL, NULL, 0),
(92, 'zwTokenSlowMovement', NULL, '2020-09-23', 'human', 'normal', '2022-02-03', 715.5, 1290, 6),
(93, 'zwTokenVoteA', NULL, '2020-09-23', 'human', 'vote', '2022-02-03', 555, 1245, 6),
(94, 'zwTokenVoteB', NULL, '2020-09-23', 'human', 'vote', '2022-02-03', 555, 1245, 6),
(95, 'zwTokenVoteC', NULL, '2020-09-23', 'human', 'vote', '2022-02-03', 555, 1245, 6);

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
-- Daten für Tabelle `video_players`
--

INSERT INTO `video_players` (`device_id`, `device_ip`, `device_name`, `device_area`, `media_id`) VALUES
(1, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(3, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(4, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(5, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(6, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(7, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(8, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(9, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(10, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(11, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(12, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(13, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(14, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(15, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(16, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(17, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(18, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(19, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(20, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(21, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(22, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(23, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(24, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(25, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(26, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(27, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(28, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(29, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(30, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(31, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(32, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(33, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(34, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(35, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(36, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(37, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(38, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(39, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(40, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(41, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(42, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(43, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(44, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(45, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(46, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(47, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(48, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(49, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(50, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(51, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(52, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(53, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(54, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(55, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(56, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(57, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(58, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(59, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(60, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(61, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(62, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(63, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(64, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(65, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(66, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(67, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(68, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(69, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(70, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(71, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(72, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(73, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(74, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(75, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(76, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(77, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(78, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(79, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(80, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(81, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(82, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(83, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(84, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(85, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(86, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(87, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(88, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(89, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(90, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(91, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(92, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(93, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(94, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(95, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(96, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(97, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(98, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(99, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(100, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(101, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(102, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(103, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(104, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(105, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(106, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(107, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(108, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(109, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(110, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(111, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(112, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(113, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(114, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(115, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(116, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(117, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(118, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(119, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(120, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(121, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(122, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(123, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(124, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(125, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(126, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(127, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(128, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(129, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(130, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(131, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(132, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(133, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(134, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(135, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(136, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(137, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(138, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(139, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(140, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(141, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(142, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(143, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(144, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(145, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(146, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(147, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(148, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(149, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(150, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(151, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(152, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(153, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(154, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(155, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(156, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(157, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(158, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(159, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(160, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(161, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(162, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(163, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(164, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(165, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(166, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(167, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(168, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(169, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(170, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(171, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(172, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(173, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(174, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(175, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(176, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(177, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(178, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(179, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(180, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(181, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(182, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(183, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(184, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(185, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(186, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(187, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(188, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(189, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(190, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(191, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(192, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(193, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(194, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(195, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(196, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(197, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(198, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(199, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(200, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(201, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(202, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(203, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(204, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(205, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(206, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(207, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(208, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(209, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(210, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(211, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(212, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(213, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(214, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(215, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(216, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(217, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(218, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(219, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(220, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(221, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(222, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(223, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(224, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(225, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(226, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(227, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(228, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(229, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(230, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(231, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(232, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(233, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(234, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(235, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(236, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(237, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(238, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(239, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(240, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(241, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(242, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(243, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(244, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(245, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(246, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(247, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(248, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(249, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(250, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(251, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(252, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(253, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(254, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(255, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(256, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(257, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(258, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(259, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(260, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(261, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(262, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(263, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(264, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(265, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(266, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(267, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(268, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(269, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(270, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(271, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(272, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(273, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(274, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(275, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(276, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(277, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(278, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(279, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(280, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(281, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(282, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(283, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(284, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(285, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(286, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(287, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(288, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(289, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(290, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(291, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(292, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(293, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(294, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(295, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(296, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(297, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(298, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(299, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(300, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(301, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(302, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(303, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(304, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(305, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(306, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(307, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(308, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(309, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(310, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(311, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(312, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(313, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(314, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(315, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(316, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(317, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(318, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(319, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(320, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(321, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(322, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(323, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(324, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(325, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(326, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(327, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(328, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(329, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(330, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(331, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(332, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(333, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(334, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(335, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(336, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(337, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(338, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(339, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(340, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(341, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(342, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(343, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(344, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(345, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(346, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(347, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(348, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(349, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(350, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(351, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(352, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(353, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(354, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(355, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(356, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(357, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(358, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(359, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(360, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(361, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(362, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(363, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(364, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(365, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(366, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(367, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(368, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(369, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(370, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(371, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(372, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(373, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(374, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(375, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(376, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(377, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(378, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(379, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(380, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(381, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(382, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(383, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(384, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(385, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(386, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(387, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(388, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(389, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(390, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(391, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(392, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(393, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(394, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(395, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(396, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(397, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(398, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(399, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(400, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(401, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(402, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(403, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(404, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(405, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(406, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(407, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(408, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(409, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(410, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(411, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(412, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(413, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(414, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(415, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(416, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(417, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(418, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(419, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(420, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(421, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(422, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(423, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(424, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(425, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(426, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(427, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(428, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(429, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(430, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(431, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(432, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(433, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(434, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(435, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(436, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(437, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(438, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(439, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(440, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(441, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(442, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(443, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(444, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(445, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(446, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(447, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(448, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(449, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(450, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(451, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(452, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(453, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(454, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(455, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(456, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(457, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(458, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(459, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(460, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(461, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(462, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(463, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(464, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(465, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(466, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(467, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(468, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(469, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(470, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(471, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(472, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(473, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(474, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(475, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(476, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(477, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(478, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(479, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(480, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(481, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(482, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(483, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(484, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(485, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(486, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(487, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(488, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(489, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(490, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(491, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(492, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(493, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(494, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(495, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(496, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(497, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(498, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(499, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(500, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(501, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(502, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(503, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(504, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(505, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(506, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(507, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(508, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(509, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(510, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(511, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(512, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(513, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(514, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(515, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(516, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(517, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(518, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(519, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(520, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(521, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(522, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(523, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(524, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(525, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(526, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(527, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(528, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(529, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(530, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(531, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(532, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(533, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(534, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(535, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(536, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(537, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(538, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(539, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(540, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(541, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(542, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(543, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(544, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(545, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(546, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(547, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(548, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(549, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(550, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(551, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(552, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(553, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(554, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(555, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(556, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(557, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(558, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(559, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(560, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(561, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(562, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(563, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(564, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(565, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(566, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(567, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(568, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(569, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(570, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(571, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(572, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(573, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(574, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(575, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(576, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(577, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(578, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(579, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(580, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(581, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(582, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(583, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(584, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(585, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(586, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(587, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(588, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(589, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(590, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(591, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(592, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(593, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(594, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(595, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(596, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(597, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(598, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(599, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(600, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(601, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(602, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(603, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(604, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(605, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(606, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(607, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(608, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(609, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(610, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(611, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(612, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(613, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(614, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(615, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(616, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(617, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(618, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(619, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(620, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(621, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(622, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(623, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(624, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(625, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(626, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(627, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(628, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(629, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(630, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(631, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(632, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(633, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(634, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(635, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(636, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(637, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(638, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(639, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(640, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(641, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(642, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(643, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(644, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(645, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(646, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(647, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(648, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(649, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(650, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(651, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(652, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(653, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(654, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(655, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(656, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(657, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(658, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(659, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(660, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(661, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(662, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(663, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(664, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(665, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(666, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(667, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(668, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(669, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(670, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(671, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(672, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(673, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(674, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(675, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(676, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(677, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(678, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(679, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(680, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(681, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(682, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(683, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(684, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(685, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(686, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(687, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(688, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(689, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(690, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(691, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(692, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(693, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(694, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(695, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(696, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(697, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(698, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(699, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(700, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(701, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(702, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(703, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(704, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(705, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(706, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(707, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(708, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(709, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(710, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(711, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(712, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(713, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(714, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(715, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(716, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(717, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(718, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(719, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(720, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(721, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(722, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(723, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(724, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(725, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(726, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(727, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(728, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(729, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(730, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(731, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(732, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(733, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(734, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(735, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(736, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(737, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(738, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(739, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(740, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(741, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(742, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(743, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(744, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(745, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(746, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(747, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(748, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(749, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(750, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(751, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(752, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(753, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(754, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(755, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(756, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(757, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(758, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(759, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(760, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(761, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(762, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(763, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(764, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(765, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(766, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(767, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(768, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(769, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(770, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(771, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(772, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(773, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(774, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(775, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(776, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(777, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(778, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy');
INSERT INTO `video_players` (`device_id`, `device_ip`, `device_name`, `device_area`, `media_id`) VALUES
(779, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(780, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(781, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(782, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(783, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(784, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(785, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(786, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(787, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(788, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(789, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(790, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(791, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(792, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(793, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(794, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(795, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(796, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(797, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(798, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(799, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(800, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(801, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(802, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(803, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(804, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(805, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(806, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(807, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(808, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(809, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(810, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(811, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(812, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(813, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(814, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(815, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(816, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(817, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(818, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(819, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(820, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(821, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(822, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(823, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(824, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(825, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(826, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(827, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(828, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(829, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(830, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(831, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(832, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(833, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(834, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(835, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(836, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(837, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(838, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(839, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(840, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(841, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(842, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(843, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(844, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(845, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(846, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(847, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(848, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(849, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(850, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(851, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(852, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(853, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(854, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(855, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(856, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(857, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(858, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(859, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(860, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(861, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(862, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(863, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(864, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(865, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(866, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(867, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(868, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(869, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(870, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(871, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(872, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(873, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(874, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(875, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(876, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(877, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(878, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(879, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(880, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(881, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(882, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(883, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(884, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(885, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(886, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(887, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(888, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(889, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(890, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(891, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(892, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(893, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(894, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(895, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(896, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(897, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(898, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(899, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(900, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(901, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(902, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(903, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(904, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(905, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(906, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(907, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(908, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(909, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(910, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(911, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(912, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(913, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(914, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(915, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(916, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(917, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(918, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(919, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(920, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(921, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(922, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(923, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(924, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(925, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(926, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(927, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(928, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(929, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(930, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(931, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(932, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(933, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(934, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(935, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(936, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(937, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(938, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(939, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(940, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(941, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(942, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(943, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(944, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(945, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(946, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(947, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(948, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(949, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(950, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(951, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(952, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(953, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(954, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(955, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(956, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(957, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(958, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(959, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(960, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(961, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(962, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(963, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(964, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(965, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(966, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(967, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(968, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(969, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(970, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(971, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(972, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(973, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(974, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(975, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(976, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(977, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(978, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(979, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(980, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(981, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(982, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(983, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(984, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(985, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(986, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(987, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(988, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(989, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(990, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(991, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(992, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(993, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(994, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(995, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(996, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(997, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(998, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(999, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1000, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1001, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1002, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1003, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1004, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1005, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1006, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1007, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1008, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1009, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1010, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1011, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1012, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1013, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1014, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1015, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1016, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1017, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1018, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1019, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1020, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1021, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1022, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1023, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1024, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1025, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1026, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1027, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1028, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1029, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1030, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1031, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1032, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1033, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1034, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1035, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1036, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1037, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1038, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1039, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1040, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1041, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1042, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1043, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1044, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1045, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1046, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1047, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1048, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1049, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1050, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1051, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1052, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1053, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1054, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1055, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1056, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1057, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1058, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1059, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1060, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1061, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1062, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1063, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1064, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1065, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1066, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1067, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1068, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1069, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1070, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1071, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1072, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1073, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1074, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1075, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1076, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1077, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1078, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1079, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1080, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1081, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1082, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1083, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1084, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1085, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1086, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1087, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1088, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1089, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1090, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1091, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1092, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1093, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1094, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1095, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1096, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1097, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1098, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1099, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1100, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1101, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1102, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1103, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1104, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1105, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1106, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1107, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1108, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1109, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1110, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1111, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1112, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1113, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1114, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1115, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1116, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1117, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1118, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1119, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1120, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1121, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1122, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1123, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1124, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1125, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1126, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1127, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1128, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1129, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1130, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1131, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1132, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1133, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1134, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1135, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1136, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1137, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1138, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1139, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1140, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1141, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1142, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1143, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1144, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1145, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1146, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1147, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1148, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1149, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1150, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1151, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1152, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1153, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1154, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1155, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1156, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1157, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1158, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1159, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1160, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1161, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1162, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1163, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1164, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1165, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1166, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1167, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1168, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1169, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1170, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1171, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1172, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1173, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1174, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1175, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1176, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1177, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1178, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1179, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1180, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1181, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1182, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1183, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1184, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1185, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1186, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1187, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1188, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1189, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1190, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1191, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1192, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1193, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1194, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1195, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1196, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1197, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1198, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1199, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1200, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1201, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1202, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1203, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1204, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1205, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1206, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1207, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1208, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1209, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1210, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1211, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1212, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1213, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1214, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1215, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1216, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1217, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1218, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1219, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1220, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1221, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1222, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1223, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1224, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1225, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1226, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1227, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1228, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1229, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1230, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1231, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1232, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1233, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1234, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1235, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1236, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1237, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1238, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1239, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1240, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1241, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1242, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1243, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1244, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1245, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1246, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1247, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1248, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1249, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1250, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1251, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1252, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1253, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1254, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1255, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1256, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1257, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1258, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1259, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1260, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1261, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1262, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1263, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1264, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1265, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1266, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1267, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1268, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1269, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1270, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1271, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1272, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1273, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1274, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1275, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1276, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1277, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1278, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1279, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1280, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1281, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1282, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1283, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1284, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1285, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1286, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1287, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1288, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1289, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1290, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1291, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1292, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1293, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1294, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1295, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1296, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1297, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1298, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1299, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1300, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1301, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1302, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1303, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1304, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1305, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1306, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1307, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1308, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1309, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1310, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1311, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1312, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1313, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1314, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1315, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1316, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1317, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1318, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1319, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1320, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1321, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1322, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1323, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1324, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1325, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1326, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1327, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1328, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1329, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1330, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1331, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1332, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1333, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1334, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1335, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1336, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1337, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1338, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1339, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1340, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1341, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1342, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1343, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1344, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1345, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1346, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1347, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1348, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1349, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1350, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1351, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1352, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1353, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1354, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1355, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1356, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1357, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1358, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1359, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1360, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1361, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1362, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1363, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1364, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1365, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1366, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1367, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1368, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1369, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1370, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1371, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1372, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1373, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1374, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1375, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1376, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1377, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1378, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1379, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1380, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1381, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1382, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1383, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1384, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1385, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1386, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1387, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1388, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1389, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1390, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1391, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1392, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1393, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1394, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1395, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1396, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1397, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1398, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1399, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1400, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1401, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1402, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1403, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1404, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1405, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1406, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1407, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1408, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1409, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1410, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1411, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1412, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1413, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1414, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1415, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1416, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1417, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1418, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1419, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1420, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1421, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1422, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1423, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1424, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1425, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1426, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1427, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1428, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1429, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1430, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1431, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1432, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1433, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1434, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1435, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1436, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1437, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1438, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1439, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1440, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1441, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1442, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1443, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1444, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1445, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1446, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1447, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1448, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1449, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1450, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1451, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1452, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1453, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1454, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1455, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1456, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1457, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1458, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1459, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1460, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1461, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1462, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1463, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1464, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1465, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1466, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1467, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1468, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1469, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1470, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1471, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1472, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1473, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1474, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1475, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1476, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1477, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1478, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1479, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1480, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1481, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1482, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1483, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1484, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1485, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1486, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1487, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1488, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1489, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1490, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1491, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1492, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1493, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1494, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1495, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1496, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1497, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1498, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1499, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1500, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1501, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1502, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1503, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1504, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1505, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1506, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1507, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1508, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1509, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1510, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1511, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1512, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1513, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1514, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1515, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1516, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1517, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1518, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1519, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1520, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1521, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1522, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1523, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1524, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1525, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1526, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1527, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1528, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1529, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1530, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1531, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1532, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1533, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1534, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1535, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1536, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1537, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1538, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1539, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1540, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1541, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1542, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations');
INSERT INTO `video_players` (`device_id`, `device_ip`, `device_name`, `device_area`, `media_id`) VALUES
(1543, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1544, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1545, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1546, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1547, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1548, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1549, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1550, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1551, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1552, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1553, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1554, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1555, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1556, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1557, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1558, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1559, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1560, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1561, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1562, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1563, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1564, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1565, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1566, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1567, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1568, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1569, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1570, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1571, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1572, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1573, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1574, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1575, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1576, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1577, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1578, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1579, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1580, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1581, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1582, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1583, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1584, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1585, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1586, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1587, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1588, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1589, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1590, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1591, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1592, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1593, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1594, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1595, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1596, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1597, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1598, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1599, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1600, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1601, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1602, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1603, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1604, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1605, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1606, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1607, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1608, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1609, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1610, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1611, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1612, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1613, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1614, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1615, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1616, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1617, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1618, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1619, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1620, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1621, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1622, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1623, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1624, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1625, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1626, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1627, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1628, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1629, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1630, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1631, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1632, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1633, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1634, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1635, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1636, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1637, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1638, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1639, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1640, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1641, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1642, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1643, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1644, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1645, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1646, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1647, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1648, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1649, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1650, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1651, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1652, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1653, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1654, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1655, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1656, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1657, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1658, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1659, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1660, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1661, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1662, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1663, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1664, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1665, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1666, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1667, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1668, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1669, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1670, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1671, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1672, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1673, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1674, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1675, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1676, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1677, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1678, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1679, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1680, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1681, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1682, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1683, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1684, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1685, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1686, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1687, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1688, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1689, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1690, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1691, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1692, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1693, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1694, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1695, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1696, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1697, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1698, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1699, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1700, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1701, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1702, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1703, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1704, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1705, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1706, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1707, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1708, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1709, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1710, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1711, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1712, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1713, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1714, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1715, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1716, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1717, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1718, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1719, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1720, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1721, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1722, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1723, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1724, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1725, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1726, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1727, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1728, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1729, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1730, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1731, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1732, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1733, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1734, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1735, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1736, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1737, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1738, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1739, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1740, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1741, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1742, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1743, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1744, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1745, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1746, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1747, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1748, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1749, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1750, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1751, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1752, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1753, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1754, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1755, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1756, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1757, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1758, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1759, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1760, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1761, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1762, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1763, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1764, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1765, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1766, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1767, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1768, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1769, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1770, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1771, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1772, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1773, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1774, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1775, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1776, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1777, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1778, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1779, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1780, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1781, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1782, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1783, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1784, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1785, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1786, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1787, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1788, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1789, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1790, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1791, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1792, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1793, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1794, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1795, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1796, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1797, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1798, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1799, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1800, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1801, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1802, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1803, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1804, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1805, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1806, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1807, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1808, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1809, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1810, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1811, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1812, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1813, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1814, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1815, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1816, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1817, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1818, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1819, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1820, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1821, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1822, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1823, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1824, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1825, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1826, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1827, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1828, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1829, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1830, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1831, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1832, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1833, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1834, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1835, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1836, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1837, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1838, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1839, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1840, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1841, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1842, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1843, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1844, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1845, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1846, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1847, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1848, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1849, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1850, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1851, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1852, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1853, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1854, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1855, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1856, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1857, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1858, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1859, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1860, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1861, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1862, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1863, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1864, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1865, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1866, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1867, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1868, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1869, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1870, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1871, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1872, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1873, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1874, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1875, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1876, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1877, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1878, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1879, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1880, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1881, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1882, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1883, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1884, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1885, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1886, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1887, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1888, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1889, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1890, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1891, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1892, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1893, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1894, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1895, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1896, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1897, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1898, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1899, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1900, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1901, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1902, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1903, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1904, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1905, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1906, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1907, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1908, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1909, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1910, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1911, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1912, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1913, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1914, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1915, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1916, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1917, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1918, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1919, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1920, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1921, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1922, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1923, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1924, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1925, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1926, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1927, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1928, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1929, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1930, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(1931, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1932, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1933, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1934, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1935, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1936, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1937, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1938, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1939, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1940, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1941, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1942, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1943, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1944, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1945, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1946, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1947, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1948, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1949, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1950, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1951, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1952, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1953, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1954, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1955, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1956, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1957, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1958, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1959, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1960, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1961, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1962, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1963, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1964, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1965, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1966, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1967, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1968, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1969, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1970, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(1971, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(1972, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1973, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(1974, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1975, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1976, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1977, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(1978, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1979, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1980, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1981, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1982, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(1983, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(1984, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(1985, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(1986, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(1987, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(1988, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(1989, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1990, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(1991, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(1992, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(1993, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(1994, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(1995, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(1996, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(1997, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(1998, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(1999, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2000, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2001, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2002, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2003, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2004, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2005, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2006, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2007, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2008, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2009, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2010, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2011, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2012, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2013, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2014, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2015, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2016, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2017, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2018, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2019, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2020, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2021, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2022, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2023, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2024, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2025, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2026, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2027, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2028, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2029, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2030, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2031, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2032, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2033, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2034, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2035, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2036, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2037, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2038, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2039, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2040, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2041, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2042, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2043, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2044, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2045, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(2046, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2047, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2048, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2049, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2050, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2051, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2052, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2053, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2054, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2055, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2056, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2057, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2058, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2059, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2060, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2061, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2062, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2063, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2064, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2065, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2066, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2067, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2068, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2069, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2070, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2071, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2072, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2073, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2074, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2075, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2076, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2077, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2078, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2079, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2080, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2081, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2082, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2083, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2084, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2085, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2086, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2087, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2088, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2089, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2090, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2091, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2092, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(2093, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2094, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2095, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2096, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2097, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2098, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2099, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2100, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2101, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2102, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2103, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2104, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2105, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2106, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2107, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2108, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2109, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2110, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2111, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2112, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2113, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2114, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2115, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2116, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2117, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2118, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2119, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2120, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2121, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2122, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2123, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2124, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2125, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2126, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2127, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2128, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2129, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2130, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2131, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2132, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2133, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2134, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2135, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2136, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2137, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2138, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2139, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2140, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2141, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2142, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2143, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2144, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2145, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2146, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2147, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2148, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2149, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2150, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2151, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2152, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2153, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2154, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2155, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2156, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2157, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2158, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2159, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2160, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2161, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2162, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2163, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2164, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2165, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2166, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2167, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2168, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2169, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2170, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2171, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2172, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2173, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2174, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2175, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2176, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2177, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2178, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2179, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2180, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2181, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(2182, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2183, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2184, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2185, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2186, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2187, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2188, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2189, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2190, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2191, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2192, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2193, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2194, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2195, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2196, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2197, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2198, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2199, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2200, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2201, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2202, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2203, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2204, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2205, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2206, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2207, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2208, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2209, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2210, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2211, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2212, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2213, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2214, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2215, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2216, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2217, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2218, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2219, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2220, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2221, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2222, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2223, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2224, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2225, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2226, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2227, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2228, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2229, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2230, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2231, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2232, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2233, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2234, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2235, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2236, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2237, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2238, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2239, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2240, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2241, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2242, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2243, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2244, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2245, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2246, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2247, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2248, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(2249, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2250, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2251, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2252, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2253, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2254, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2255, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2256, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2257, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2258, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2259, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2260, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2261, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2262, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2263, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2264, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2265, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2266, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2267, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2268, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2269, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2270, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2271, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2272, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2273, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2274, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2275, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2276, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2277, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2278, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2279, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2280, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2281, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2282, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2283, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2284, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2285, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2286, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2287, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2288, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2289, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2290, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2291, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2292, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2293, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2294, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2295, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2296, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2297, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2298, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2299, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2300, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2301, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2302, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2303, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2304, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2305, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife');
INSERT INTO `video_players` (`device_id`, `device_ip`, `device_name`, `device_area`, `media_id`) VALUES
(2306, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2307, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2308, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2309, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2310, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2311, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2312, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2313, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2314, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2315, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2316, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2317, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2318, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2319, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2320, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2321, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2322, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2323, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2324, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2325, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2326, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2327, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2328, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2329, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2330, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2331, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(2332, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2333, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2334, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2335, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2336, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2337, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2338, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2339, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2340, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2341, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2342, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2343, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2344, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2345, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2346, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2347, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2348, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2349, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2350, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2351, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2352, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2353, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2354, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2355, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2356, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2357, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2358, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2359, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2360, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2361, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2362, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2363, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2364, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2365, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2366, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2367, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2368, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2369, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2370, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2371, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2372, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2373, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2374, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2375, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2376, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2377, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2378, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2379, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(2380, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2381, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2382, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2383, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2384, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2385, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2386, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2387, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2388, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2389, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2390, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2391, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2392, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2393, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2394, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2395, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2396, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2397, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2398, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2399, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2400, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2401, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2402, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2403, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2404, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2405, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2406, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2407, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2408, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2409, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2410, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2411, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2412, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2413, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2414, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2415, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2416, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2417, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2418, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2419, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2420, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2421, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2422, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2423, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2424, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2425, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2426, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2427, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2428, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2429, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2430, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2431, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2432, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2433, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2434, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2435, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2436, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2437, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2438, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2439, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2440, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2441, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2442, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2443, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2444, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2445, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2446, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2447, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2448, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2449, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2450, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2451, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2452, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2453, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2454, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2455, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2456, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2457, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2458, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2459, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2460, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2461, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2462, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2463, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2464, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2465, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2466, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2467, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2468, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2469, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(2470, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2471, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2472, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2473, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2474, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2475, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2476, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2477, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2478, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2479, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2480, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2481, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2482, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2483, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2484, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2485, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2486, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2487, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2488, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2489, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2490, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2491, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2492, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2493, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2494, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2495, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2496, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2497, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2498, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2499, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2500, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2501, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2502, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2503, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2504, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2505, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2506, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2507, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2508, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2509, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2510, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2511, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2512, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2513, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2514, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2515, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2516, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2517, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2518, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2519, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2520, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2521, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2522, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2523, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2524, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2525, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2526, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2527, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2528, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2529, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2530, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2531, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2532, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2533, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2534, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2535, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2536, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2537, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2538, '172.25.2.83 ', 'DT-NK2-PC-2', 'technology', 'climate-controversy'),
(2539, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2540, '172.25.2.85 ', 'DT-EE1-PC-1', 'technology', 'nuclear-controversy'),
(2541, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2542, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2543, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2544, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2545, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2546, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2547, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2548, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2549, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2550, '172.25.2.130 ', 'DN-NL4-PC-2', 'nature', 'bioinspiration-expert'),
(2551, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2552, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2553, '172.25.2.113 ', 'DM-KO2-PC-3', 'human', 'cities-quito'),
(2554, '172.25.2.91 ', 'DT-MM5-PC-1', 'technology', 'cyborgs'),
(2555, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2556, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2557, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2558, '172.25.2.90 ', 'DT-MM4-PC-1', 'technology', 'bci'),
(2559, '172.25.2.84 ', 'DT-NK3-PC-1', 'technology', 'engineered-food'),
(2560, '172.25.2.124 ', 'DN-KL4-PC-2', 'nature', 'design'),
(2561, '172.25.2.104 ', 'DM-RE1-PC-1', 'human', 'production-roles'),
(2562, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2563, '172.25.2.108 ', 'DM-RE3-PC-1', 'human', 'ulla-sladek'),
(2564, '172.25.2.125 ', 'DN-KL5-PC-1', 'nature', 'corporations'),
(2565, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2566, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2567, '172.25.2.81 ', 'DT-NK1-PC-1', 'technology', 'nano-racer'),
(2568, '172.25.2.106 ', 'DM-RE2-PC-2', 'human', 'supply-expert'),
(2569, '172.25.2.109 ', 'DM-RE3-PC-2', 'human', 'resilient-systems'),
(2570, '172.25.2.127 ', 'DN-NE2-PC-1', 'nature', 'energy-expert'),
(2571, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby'),
(2572, '172.25.2.98 ', 'DT-GT2-PC-2', 'technology', 'precision-medicine'),
(2573, '172.25.2.111 ', 'DM-KO2-PC-1', 'human', 'cities-recife'),
(2574, '172.25.2.128 ', 'DN-NL3-PC-1', 'nature', 'new-medicine'),
(2575, '172.25.2.112 ', 'DM-KO2-PC-2', 'human', 'cities-tuebingen'),
(2576, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2577, '172.25.2.110 ', 'DM-KO1-PC-1', 'human', 'economy'),
(2578, '172.25.2.97 ', 'DT-GT2-PC1', 'technology', 'designerbaby');

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
  MODIFY `token_db_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=128;

--
-- AUTO_INCREMENT für Tabelle `video_players`
--
ALTER TABLE `video_players`
  MODIFY `device_id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2579;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
