/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created by Roy@20231213
	Run at DBCRM@MessageNotification
	Task: Create tables for NotificationCenter
	Steps:
		1. Create new Database
*/

/***** Create new Database ****/
-- USE master
-- GO

-- DROP DATABASE IF EXISTS MessageNotification
-- GO

CREATE DATABASE [MessageNotification] ON PRIMARY (
		NAME = N'MessageNotification'
		,FILENAME = N'G:\SQLSERVER2019_DEVDB053\IBC_DB\MessageNotification.mdf'
		,SIZE = 5 MB
		,FILEGROWTH = 32 MB
	)
	,FILEGROUP [MNC] (
		NAME = N'MNC'
		,FILENAME = N'G:\SQLSERVER2019_DEVDB053\IBC_DB\MNC.ndf'
		,SIZE = 5 MB
		,FILEGROWTH = 32 MB
	)
	LOG ON (
		NAME = N'MessageNotification_log'
		,FILENAME = N'G:\SQLSERVER2019_DEVDB053\IBC_DB\MessageNotification_log.ldf'
		,SIZE = 32 MB
		,FILEGROWTH = 32 MB
	)
GO

USE [MessageNotification]
GO

CREATE USER [bodbAdminNet] FOR LOGIN [bodbAdminNet] WITH DEFAULT_SCHEMA=[dbo]
GO