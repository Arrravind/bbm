-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 07, 2026 at 06:07 AM
-- Server version: 11.8.3-MariaDB-log
-- PHP Version: 7.2.34

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `u888578780_bbm`
--

-- --------------------------------------------------------

--
-- Table structure for table `team_lead_tracking`
--

CREATE TABLE `team_lead_tracking` (
  `tracking_id` int(11) NOT NULL,
  `lead_id` int(11) NOT NULL,
  `service_type` varchar(100) NOT NULL COMMENT 'makeup, photography, catering, decor, etc. - from leads.services_required',
  `current_status_id` int(11) NOT NULL DEFAULT 1,
  `team_member_id` int(11) DEFAULT NULL COMMENT 'Current telecaller working on this lead',
  `is_claimed` tinyint(1) DEFAULT 0 COMMENT '1 if claimed from pool, 0 if in pool',
  `claimed_at` datetime DEFAULT NULL,
  `assigned_artist_id` int(11) DEFAULT NULL,
  `preliminary_artist_id` int(11) DEFAULT NULL,
  `last_contact_date` datetime DEFAULT NULL,
  `last_contact_type` enum('call','whatsapp','sms','email','other') DEFAULT NULL,
  `follow_up_date` date DEFAULT NULL,
  `follow_up_notes` text DEFAULT NULL,
  `lead_rating` int(1) DEFAULT NULL COMMENT '1-5 rating',
  `lead_feedback` text DEFAULT NULL,
  `general_notes` longtext DEFAULT NULL,
  `total_contact_attempts` int(11) DEFAULT 0,
  `created_by` int(11) NOT NULL COMMENT 'Which team member created this tracking record',
  `last_updated_by` int(11) DEFAULT NULL COMMENT 'Which team member last updated',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `team_lead_tracking`
--

INSERT INTO `team_lead_tracking` (`tracking_id`, `lead_id`, `service_type`, `current_status_id`, `team_member_id`, `is_claimed`, `claimed_at`, `assigned_artist_id`, `preliminary_artist_id`, `last_contact_date`, `last_contact_type`, `follow_up_date`, `follow_up_notes`, `lead_rating`, `lead_feedback`, `general_notes`, `total_contact_attempts`, `created_by`, `last_updated_by`, `created_at`, `updated_at`) VALUES
(1, 1284, '[\"Makeup\"]', 1, 1, 1, '2026-03-05 20:29:40', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, 1, '2026-03-05 20:24:50', '2026-03-05 20:29:40'),
(2, 1285, '[\"Makeup\"]', 1, 1, 1, '2026-03-07 04:56:10', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, 1, '2026-03-05 20:42:12', '2026-03-07 04:56:10'),
(3, 1286, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-06 01:47:40', '2026-03-06 01:47:40'),
(4, 1287, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-06 05:19:41', '2026-03-06 05:19:41'),
(5, 1288, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-06 05:22:19', '2026-03-06 05:22:19'),
(6, 1289, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-06 05:24:20', '2026-03-06 05:24:20'),
(7, 1290, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-06 05:26:21', '2026-03-06 05:26:21'),
(8, 1291, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-06 06:05:10', '2026-03-06 06:05:10'),
(9, 1292, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-06 13:06:43', '2026-03-06 13:06:43'),
(10, 1293, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-07 02:09:20', '2026-03-07 02:09:20'),
(11, 1294, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-07 02:10:24', '2026-03-07 02:10:24'),
(12, 1295, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-07 02:14:12', '2026-03-07 02:14:12'),
(13, 1296, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-07 04:37:27', '2026-03-07 04:37:27'),
(14, 1297, '[\"Makeup\"]', 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL, '2026-03-07 06:06:07', '2026-03-07 06:06:07');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `team_lead_tracking`
--
ALTER TABLE `team_lead_tracking`
  ADD PRIMARY KEY (`tracking_id`),
  ADD KEY `idx_lead_id` (`lead_id`),
  ADD KEY `idx_service_type` (`service_type`),
  ADD KEY `idx_current_status` (`current_status_id`),
  ADD KEY `idx_team_member` (`team_member_id`),
  ADD KEY `idx_is_claimed` (`is_claimed`),
  ADD KEY `idx_created_by` (`created_by`),
  ADD KEY `idx_last_updated_by` (`last_updated_by`),
  ADD KEY `idx_assigned_artist` (`assigned_artist_id`),
  ADD KEY `idx_follow_up_date` (`follow_up_date`),
  ADD KEY `idx_created_at` (`created_at`),
  ADD KEY `idx_composite_status_claimed` (`current_status_id`,`is_claimed`),
  ADD KEY `idx_composite_team_status` (`team_member_id`,`current_status_id`),
  ADD KEY `idx_service_type_status` (`service_type`,`current_status_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `team_lead_tracking`
--
ALTER TABLE `team_lead_tracking`
  MODIFY `tracking_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `team_lead_tracking`
--
ALTER TABLE `team_lead_tracking`
  ADD CONSTRAINT `fk_tracking_artist` FOREIGN KEY (`assigned_artist_id`) REFERENCES `elite_clients` (`id`),
  ADD CONSTRAINT `fk_tracking_created_by` FOREIGN KEY (`created_by`) REFERENCES `teams` (`team_id`),
  ADD CONSTRAINT `fk_tracking_lead` FOREIGN KEY (`lead_id`) REFERENCES `leads` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_tracking_status` FOREIGN KEY (`current_status_id`) REFERENCES `status_master` (`status_id`),
  ADD CONSTRAINT `fk_tracking_team` FOREIGN KEY (`team_member_id`) REFERENCES `teams` (`team_id`),
  ADD CONSTRAINT `fk_tracking_updated_by` FOREIGN KEY (`last_updated_by`) REFERENCES `teams` (`team_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
