-- phpMyAdmin SQL Dump
-- version 4.1.9
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Erstellungszeit: 19. Mrz 2014 um 22:20
-- Server Version: 5.5.33
-- PHP-Version: 5.3.17

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Datenbank: `mydyndns`
--
CREATE DATABASE IF NOT EXISTS `mydyndns` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE `mydyndns`;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `config`
--

DROP TABLE IF EXISTS `config`;
CREATE TABLE IF NOT EXISTS `config` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL DEFAULT '',
  `value` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COMMENT='DynDNS Settings' AUTO_INCREMENT=7 ;

--
-- Daten für Tabelle `config`
--

INSERT INTO `config` (`id`, `name`, `value`) VALUES
(1, 'version', '1'),
(2, 'loglevel', '3'),
(3, 'zonefile_directory', '/var/lib/named/dyndns'),
(4, 'dns_host', '127.0.0.1'),
(5, 'dns_port', '953'),
(6, 'dns_key', '');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `hosts`
--

DROP TABLE IF EXISTS `hosts`;
CREATE TABLE IF NOT EXISTS `hosts` (
  `host_id` int(10) unsigned NOT NULL,
  `domain` varchar(255) NOT NULL,
  `description` varchar(255) NOT NULL,
  `host` varchar(255) NOT NULL,
  `ip` varchar(15) NOT NULL,
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `modified` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`host_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Table for Host entries';

--
-- Daten für Tabelle `hosts`
--

INSERT INTO `hosts` (`host_id`, `domain`, `description`, `host`, `ip`, `created`, `modified`, `active`) VALUES
(0, 'dyn.example.com', '', 'hostname', '127.0.0.1', '2014-03-18 00:00:00', '2014-03-19 00:00:09', 1);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `hosts_to_users`
--

DROP TABLE IF EXISTS `hosts_to_users`;
CREATE TABLE IF NOT EXISTS `hosts_to_users` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `host_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=2 ;

--
-- Daten für Tabelle `hosts_to_users`
--

INSERT INTO `hosts_to_users` (`id`, `host_id`, `user_id`) VALUES
(1, 0, 0);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `logs`
--

DROP TABLE IF EXISTS `logs`;
CREATE TABLE IF NOT EXISTS `logs` (
  `log_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `timestamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `username` varchar(255) NOT NULL,
  `action` varchar(255) NOT NULL,
  `data` text NOT NULL,
  PRIMARY KEY (`log_id`),
  KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Internal Log';

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE IF NOT EXISTS `users` (
  `user_id` int(10) unsigned NOT NULL,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `modified` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='DynDNS Users';

--
-- Daten für Tabelle `users`
--

INSERT INTO `users` (`user_id`, `username`, `password`, `created`, `modified`, `active`) VALUES
(0, 'username', 'password', '2014-03-18 00:00:00', '2014-03-18 00:00:00', 1);

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
