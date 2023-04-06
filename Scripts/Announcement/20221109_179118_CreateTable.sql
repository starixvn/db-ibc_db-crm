/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221222@Malcolm
	DB: DBCRM-bodb_CRM
	Task: create job to import notification [RedmineId : #179118]
*/

CREATE TABLE dbo.crmAnnouncement
(
	AnnouncementId			INT IDENTITY(1, 1) PRIMARY KEY NONCLUSTERED
	,NotificationTemplateId SMALLINT
	,Title					NVARCHAR(2000)
	,SendDate				DATETIME
	,CreatedBy				INT
	,CreatedDate			DATETIME
	,Status					VARCHAR(20)
	,FileName				NVARCHAR(2000)
	,SendImmediately		BIT DEFAULT(0)
	,HeadlineNameList		NVARCHAR(MAX)
	,SiteNameList			NVARCHAR(MAX)
	,CurrencyIdList			NVARCHAR(MAX)
	,HeadlineType			TINYINT
	,UpdatedBy				INT
	,UpdatedDate			DATETIME		
) ON [DataChatBot] TEXTIMAGE_ON [DataChatBot]
GO

CREATE CLUSTERED INDEX CIX_SendDate ON dbo.crmAnnouncement (SendDate)
GO

CREATE NONCLUSTERED INDEX IX_Status ON dbo.crmAnnouncement (Status, AnnouncementId)
GO

CREATE NONCLUSTERED INDEX IX_NotificationTemplateId ON dbo.crmAnnouncement (NotificationTemplateId)
GO

CREATE TABLE dbo.crmAnnouncementContent
(
	AnnouncementId	INT
	,LanguageId		INT
	,Content		NVARCHAR(MAX)
	,CONSTRAINT PK_crmAnnouncementContent PRIMARY KEY CLUSTERED (AnnouncementId, LanguageId)
) ON [DataChatBot]
GO

CREATE TABLE dbo.crmAnnouncementHeadline
(
	AnnouncementId	INT	
	,CustId			INT
	,CONSTRAINT PK_crmAnnouncementHeadline PRIMARY KEY CLUSTERED (AnnouncementId, CustId)
) ON [DataChatBot]
GO

CREATE TABLE dbo.crmAnnouncementNotification
(
	AnnouncementId	INT
	,NotificationId INT
	,CONSTRAINT PK_crmAnnouncementNotification PRIMARY KEY CLUSTERED (AnnouncementId, NotificationId)
) ON [DataChatBot]
GO

CREATE NONCLUSTERED INDEX IX_NotificationId ON dbo.crmAnnouncementNotification(NotificationId)
GO

CREATE TABLE dbo.crmIgnoredNotificationType
(
	ConversationGroupId INT
	,NotificationTypeId SMALLINT
	,CONSTRAINT PK_crmIgnoredNotificationType PRIMARY KEY CLUSTERED (ConversationGroupId, NotificationTypeId)
) ON [DataChatBot]
GO

CREATE TABLE dbo.crmAnnouncementDirectAccount
(
	AnnouncementId	INT	
	,CustId			INT
	,CONSTRAINT PK_crmAnnouncementDirectAccount PRIMARY KEY CLUSTERED (AnnouncementId, CustId)
) ON [DataChatBot]
GO

