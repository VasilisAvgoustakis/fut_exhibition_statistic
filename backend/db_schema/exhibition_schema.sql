-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: mysql-db
-- Erstellungszeit: 11. Dez 2023 um 14:40
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
CREATE DATABASE IF NOT EXISTS `futurium_exhibition_stats` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `futurium_exhibition_stats`;

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
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
