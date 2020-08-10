USE bodb_CRM
GO

--ALTER DATABASE bodb_CRM ADD FILEGROUP DataChatBot
--GO
--ALTER DATABASE bodb_CRM ADD FILE (NAME = DataChatBot, FILENAME = 'D:\IBC_DB\bodb_CRM\DataChatBot.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP DataChatBot
--GO

CREATE TABLE dbo.crmNotification
(
	NotificationId		INT NOT NULL IDENTITY(1, 1)
	,MessageId			INT
	,NotificationTypeId	SMALLINT
	,Sender				INT
	,SendDate			DATETIME
	,Title				NVARCHAR(2000)
	,Content			NVARCHAR(MAX)
	,Status				VARCHAR(20)
	,CONSTRAINT PK_crmNotification PRIMARY KEY NONCLUSTERED
	(
		NotificationId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationHeadline
(
	NotificationId	INT NOT NULL
	,HeadlineId		INT NOT NULL
	,CONSTRAINT PK_crmNotificationHeadline PRIMARY KEY CLUSTERED
	(
		NotificationId	ASC
		,HeadlineId		ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationPIC
(
	NotificationId	INT NOT NULL
	,PicId			INT NOT NULL
	,CONSTRAINT PK_crmNotificationPIC PRIMARY KEY CLUSTERED
	(
		NotificationId	ASC
		,PicId			ASC
	)
) ON DataChatBot
GO

--DROP TABLE dbo.crmNotificationType
--GO

CREATE TABLE dbo.crmNotificationType
(
	NotificationTypeId		TINYINT NOT NULL IDENTITY(1, 1)
	,NotificationTypeName	NVARCHAR(500)
	,RecipientTypeId		TINYINT
	,ChatTypeId				TINYINT
	,SystemId				TINYINT
	,CONSTRAINT PK_crmNotificationType PRIMARY KEY CLUSTERED
	(
		NotificationTypeId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmRecipientType
(
	RecipientTypeId		TINYINT NOT NULL IDENTITY(1, 1)
	,RecipientTypeName	VARCHAR(200)
	,CONSTRAINT PK_crmRecipientType PRIMARY KEY CLUSTERED
	(
		RecipientTypeId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmChatType
(
	ChatTypeId		TINYINT NOT NULL IDENTITY(1, 1)
	,ChatTypeName	VARCHAR(50)
	,CONSTRAINT PK_crmChatType PRIMARY KEY CLUSTERED
	(
		ChatTypeId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmSystem
(
	SystemId		TINYINT NOT NULL IDENTITY(1, 1)
	,SystemName		VARCHAR(100)
	,CONSTRAINT PK_crmSystem PRIMARY KEY CLUSTERED
	(
		SystemId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationTemplate
(
	NotificationTemplateId		SMALLINT NOT NULL IDENTITY(1, 1)
	,NotificationTemplateName	NVARCHAR(1000)
	,NotificationTypeId			TINYINT
	,Title						NVARCHAR(2000)
	,Content					NVARCHAR(MAX)
	,CONSTRAINT PK_crmNotificationTemplate PRIMARY KEY CLUSTERED
	(
		NotificationTemplateId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmConversationBot
(
	ConversationBotId		TINYINT NOT NULL IDENTITY (1, 1)
	,ConversationId			VARCHAR(200)
	,ConversationBotName	NVARCHAR(1000)
	,CONSTRAINT PK_crmConversationBot PRIMARY KEY CLUSTERED
	(
		ConversationBotId ASC
	)
) ON DataChatBot
GO

--DROP TABLE dbo.crmConversationGroup
--GO

CREATE TABLE dbo.crmConversationGroup
(
	ConversationGroupId		SMALLINT NOT NULL IDENTITY (1, 1)
	,ConversationId			VARCHAR(200)
	,ConversationGroupName	NVARCHAR(1000)
	,ChatTypeId				TINYINT
	,Channel				VARCHAR(50)
	,Creator				INT
	,CreatedDate			DATETIME CONSTRAINT DF_crmConversationGroup_CreatedDate DEFAULT (GETDATE())
	,UpdatedDate			DATETIME CONSTRAINT DF_crmConversationGroup_UpdatedDate DEFAULT (GETDATE())
	,IsActive				BIT CONSTRAINT DF_crmConversationGroup_IsActive DEFAULT ((0))
	,CONSTRAINT PK_crmConversationGroup PRIMARY KEY CLUSTERED
	(
		ConversationGroupId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmConversationGroupBot
(
	ConversationGroupId SMALLINT NOT NULL
	,ConversationBotId	TINYINT NOT NULL
	,CONSTRAINT PK_crmConversationGroupBot PRIMARY KEY CLUSTERED
	(
		ConversationGroupId ASC
		,ConversationBotId	ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmConversationGroupHeadline
(
	ConversationGroupId SMALLINT NOT NULL
	,HeadlineId			INT NOT NULL
	,CONSTRAINT PK_crmConversationGroupHeadline PRIMARY KEY CLUSTERED
	(
		ConversationGroupId ASC
		,HeadlineId			ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmConversationGroupPIC
(
	ConversationGroupId SMALLINT NOT NULL
	,PicId				INT NOT NULL
	,CONSTRAINT PK_crmConversationGroupPIC PRIMARY KEY CLUSTERED
	(
		ConversationGroupId ASC
		,PicId				ASC
	)
) ON DataChatBot
GO