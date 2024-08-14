/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created by Roy@20231213
	Run at DBCRM@MessageNotification
	Task: Create tables for NotificationCenter
	Steps:
		1. Create new Database
		2. Create user and grant permission
*/

/***** Create new Database ****/
-- USE master
-- GO

-- DROP DATABASE IF EXISTS MessageNotification
-- GO

CREATE DATABASE [MessageNotification] ON PRIMARY (
		NAME = N'MessageNotification'
		,FILENAME = N'G:\SQLSERVER2019_DEVDB053\IBC_DB\MessageNotification.mdf'
		,SIZE = 512 MB
		,FILEGROWTH = 512 MB
	)
	,FILEGROUP [MNC] (
		NAME = N'MNC'
		,FILENAME = N'G:\SQLSERVER2019_DEVDB053\IBC_DB\MNC.ndf'
		,SIZE = 512 MB
		,FILEGROWTH = 512 MB
	)
	LOG ON (
		NAME = N'MessageNotification_log'
		,FILENAME = N'G:\SQLSERVER2019_DEVDB053\IBC_DB\MessageNotification_log.ldf'
		,SIZE = 512 MB
		,FILEGROWTH = 512 MB
	)
GO

USE MessageNotification
GO

CREATE USER [wsv_nap] FOR LOGIN [wsv_nap] WITH DEFAULT_SCHEMA=[dbo]
GO

CREATE USER [wsv_lap] FOR LOGIN [wsv_lap] WITH DEFAULT_SCHEMA=[dbo]
GO

CREATE USER [vnteam] FOR LOGIN [vnteam] WITH DEFAULT_SCHEMA=[dbo]
GO

ALTER ROLE [db_datareader] ADD MEMBER [vnteam]
GO