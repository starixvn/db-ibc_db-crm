/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created by Roy@20231213
	Run at DBCRM@MessageNotification
	Task: Create tables for NotificationCenter
	Steps:
		1. Create new Database
		2. Create tables & clustered index
*/

/***** Create tables & clustered index ****/

USE MessageNotification
GO
/***** SettlementResultHist ****/
DROP TABLE IF EXISTS dbo.SettlementResultHist

CREATE TABLE dbo.SettlementResultHist (
	SettlementLogID INT IDENTITY(1, 1) PRIMARY KEY
	,StatusID TINYINT NOT NULL
	,SiteDBGroupID SMALLINT NOT NULL
	,SessionID VARCHAR(50) NOT NULL
	,SeqNo SMALLINT NOT NULL
	,MatchID INT NOT NULL
	,IsTest BIT
	,ActionType TINYINT NOT NULL
	,ResultType TINYINT NOT NULL
	,SportType SMALLINT NOT NULL
	,ActualResult VARCHAR(MAX)
	,WrongResult VARCHAR(MAX)
	,ExtraInfo VARCHAR(MAX)
	,CreatedTime DATETIME NOT NULL DEFAULT GETDATE()
	,InsertedTime DATETIME NOT NULL DEFAULT GETDATE()
	,LastModifiedTime DATETIME NOT NULL DEFAULT GETDATE()
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE NONCLUSTERED INDEX [IX_RHSessionID] ON dbo.SettlementResultHist (
	SessionID
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

/***** SettlementResultHistDetail ****/
DROP TABLE IF EXISTS dbo.SettlementResultHistDetail

CREATE TABLE dbo.SettlementResultHistDetail (
	SettlementLogID INT NOT NULL
	,TransID BIGINT NOT NULL
	,CustID INT
	,ExtraInfo_Before VARCHAR(MAX)
	,ExtraInfo_After VARCHAR(MAX)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [CIX_NotifDetail] ON dbo.SettlementResultHistDetail (
	SettlementLogID
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

/***** BalanceNegativeHist ****/
DROP TABLE IF EXISTS dbo.BalanceNegativeHist

CREATE TABLE dbo.BalanceNegativeHist (
	SettlementLogID INT NOT NULL
	,LogID BIGINT NOT NULL
	,ExecDate DATETIME
	,MatchID INT
	,ActionID INT
	,CustID INT NOT NULL
	,GroupID INT
	,Balance MONEY
	,TotalBalance MONEY
	,Site VARCHAR(50)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [CIX_BalanceNegative] ON dbo.BalanceNegativeHist (
	SettlementLogID
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO
	
/***** NotiMapping ****/
DROP TABLE IF EXISTS dbo.NotiMapping

CREATE TABLE dbo.NotiMapping (
	SettlementLogID INT NOT NULL
	,NotificationID INT NOT NULL
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [CIX_NotiMapping] ON dbo.NotiMapping (
	SettlementLogID
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

/***** Notification ****/
DROP TABLE IF EXISTS dbo.Notification

CREATE TABLE dbo.Notification (
	NotificationID INT IDENTITY(1, 1) PRIMARY KEY
	,RefID INT
	,StatusID TINYINT NOT NULL
	,NotificationType TINYINT NOT NULL
	,Subject NVARCHAR(1000)
	,Content_en NVARCHAR(4000)
	,Content_ch NVARCHAR(4000)
	,Content_cs NVARCHAR(4000)
	,InsertedTime DATETIME NOT NULL DEFAULT GETDATE()
	,LastModifiedTime DATETIME NOT NULL DEFAULT GETDATE()
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE NONCLUSTERED INDEX [IX_NotiIns] ON dbo.Notification (
	InsertedTime
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

CREATE NONCLUSTERED INDEX [IX_NotiRefID] ON dbo.Notification (
	RefID
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

/***** NotificationTarget ****/
DROP TABLE IF EXISTS dbo.NotificationTarget

CREATE TABLE dbo.NotificationTarget (
	NotificationID INT NOT NULL
	,StatusID TINYINT NOT NULL
	,TargetID INT NOT NULL
	,TargetSite NVARCHAR(50)
	,ExtraInfo NVARCHAR(MAX)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [CIX_NotiTarget] ON dbo.NotificationTarget (
	NotificationID
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

/***** NotificationExtra ****/
DROP TABLE IF EXISTS dbo.NotificationExtra

CREATE TABLE dbo.NotificationExtra (
	NotificationID INT NOT NULL
	,EventDate DATE NOT NULL
	,ExtraInfo NVARCHAR(MAX)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [CIX_NotiExtra] ON dbo.NotificationExtra (
	NotificationID
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

/***** AlertRule ****/
DROP TABLE IF EXISTS dbo.AlertRule

CREATE TABLE dbo.AlertRule (
	RuleID INT PRIMARY KEY
	,RuleName VARCHAR(50)
	,RuleType VARCHAR(50)
	,SQLStatement NVARCHAR(MAX)
	,ChatGroupIDs VARCHAR(50)
	,LastScan NVARCHAR(500)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

/***** Alert ****/
DROP TABLE IF EXISTS dbo.Alert

CREATE TABLE dbo.Alert (
	AlertID INT IDENTITY(1, 1) PRIMARY KEY
	,StatusID TINYINT NOT NULL
	,RuleID INT NOT NULL
	,RefID VARCHAR(50)
	,RefExtraInfo NVARCHAR(MAX)
	,Content NVARCHAR(4000)
	,InsertedTime DATETIME DEFAULT GETDATE()
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

/***** Status ****/
DROP TABLE IF EXISTS dbo.NotiStatus

CREATE TABLE dbo.NotiStatus (
	StatusID TINYINT PRIMARY KEY
	,Status VARCHAR(50) NOT NULL UNIQUE
	,Remark VARCHAR(500)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

/***** LogAction ****/
DROP TABLE IF EXISTS dbo.LogAction

CREATE TABLE dbo.LogAction (
	ActionID TINYINT IDENTITY(1, 1) PRIMARY KEY
	,ActName VARCHAR(50)
	,Remark VARCHAR(500)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

/***** Log ****/
DROP TABLE IF EXISTS dbo.Log

CREATE TABLE dbo.Log (
	LogID BIGINT NOT NULL IDENTITY(1, 1)
	,LogTime DATETIME NOT NULL DEFAULT GETDATE()
	,RefID INT
	,ActionID TINYINT
	,UserID INT
	,LogBef NVARCHAR(MAX)
	,LogAft NVARCHAR(MAX)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [CIX_LogTime] ON dbo.Log (
	LogTime
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

CREATE NONCLUSTERED INDEX [IX_LogRefID] ON dbo.Log (
	RefID
) WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO

/***** NotiTemplate ****/
DROP TABLE IF EXISTS dbo.NotiTemplate

CREATE TABLE NotiTemplate (
	TemplateID TINYINT PRIMARY KEY
	,TemplateName VARCHAR(200)
	,Content_en NVARCHAR(4000)
	,Content_ch NVARCHAR(4000)
	,Content_cs NVARCHAR(4000)
	,RequiredParams NVARCHAR(500)
	,CreatorID INT NOT NULL
	,CreatedTime DATETIME DEFAULT GETDATE()
	,LastModifiedBy INT NOT NULL
	,LastModifiedTime DATETIME DEFAULT GETDATE()
	,Remark VARCHAR(500)
)

/***** SystemSetting ****/
DROP TABLE IF EXISTS dbo.SystemSetting

CREATE TABLE dbo.SystemSetting (
	VID INT NOT NULL PRIMARY KEY
	,VName VARCHAR(50)
	,VValue VARCHAR(500) NOT NULL
	,DataType VARCHAR(50) NOT NULL
	,Remark VARCHAR(1000)
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO