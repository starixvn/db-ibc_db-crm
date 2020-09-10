/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
	Created: 20200810@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Chatbot for CRM - New structure
*/

USE bodb_CRM
GO

ALTER DATABASE bodb_CRM ADD FILEGROUP DataChatBot
GO
ALTER DATABASE bodb_CRM ADD FILE (NAME = DataChatBot, FILENAME = 'D:\IBC_DB\bodb_CRM\DataChatBot.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP DataChatBot
GO

CREATE TABLE dbo.crmNotification
(
	NotificationId			INT NOT NULL IDENTITY(1, 1)
	,MessageId				INT
	,NotificationTypeId		SMALLINT
	,Sender					INT
	,SendDate				DATETIME
	,Title					NVARCHAR(2000)
	,Content				NVARCHAR(MAX)
	,[Status]				VARCHAR(20)
	,ResolvedRemark         NVARCHAR(2000)
	,RelatedNotificationIds VARCHAR(1000)
	,CONSTRAINT PK_crmNotification PRIMARY KEY NONCLUSTERED
	(
		NotificationId ASC
	)
) ON DataChatBot
GO

CREATE CLUSTERED INDEX CIX_crmNotification ON dbo.crmNotification (SendDate) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationType
(
	NotificationTypeId		SMALLINT NOT NULL IDENTITY(1, 1)
	,NotificationTypeName	NVARCHAR(500)
	,SystemId				TINYINT
	,CONSTRAINT PK_crmNotificationType PRIMARY KEY CLUSTERED
	(
		NotificationTypeId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationRecipientType
(
	NotificationTypeId	SMALLINT NOT NULL
	,RecipientTypeId    TINYINT NOT NULL
	,CONSTRAINT PK_crmNotificationRecipientType PRIMARY KEY CLUSTERED
	(
		NotificationTypeId,
		RecipientTypeId
	)
) ON DataChatBot
GO


CREATE TABLE dbo.crmNotificationChatType
(
	NotificationTypeId SMALLINT NOT NULL
	,ChatTypeId		   TINYINT NOT NULL
	,CONSTRAINT PK_crmNotificationChatType PRIMARY KEY CLUSTERED
	(
		NotificationTypeId,
		ChatTypeId
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


CREATE TABLE dbo.crmRecipient
(
	RecipientId INT NOT NULL IDENTITY(1, 1)
	,RecipientTypeId TINYINT NOT NULL
	,SourceId INT
	,DataSource VARCHAR(128)
	,CONSTRAINT PK_crmRecipient PRIMARY KEY CLUSTERED
	(
		RecipientId ASC
	)
) ON DataChatBot
GO

CREATE NONCLUSTERED INDEX IX_SourceId ON dbo.crmRecipient (SourceId) INCLUDE (DataSource) ON DataChatBot
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
	,NotificationTypeId			SMALLINT
	,Title						NVARCHAR(2000)
	,CONSTRAINT PK_crmNotificationTemplate PRIMARY KEY CLUSTERED
	(
		NotificationTemplateId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationTemplateContent 
(
	NotificationTemplateId  SMALLINT NOT NULL
	,LanguageId             INT NOT NULL
	,Content                NVARCHAR(MAX)
	,CONSTRAINT PK_crmNotificationTemplateContent PRIMARY KEY CLUSTERED
	(
		NotificationTemplateId,
		LanguageId
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmConversationBot
(
	BotId		INT NOT NULL 
	,BotName	NVARCHAR(1000)
	,CONSTRAINT PK_crmConversationBot PRIMARY KEY CLUSTERED
	(
		BotId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmConversationGroup
(
	ConversationGroupId		SMALLINT NOT NULL IDENTITY (1, 1)
	,ConversationId			VARCHAR(200)
	,ConversationGroupName	NVARCHAR(1000)
	,ChatTypeId				TINYINT
	,Creator				INT
	,CreatedDate			DATETIME CONSTRAINT DF_crmConversationGroup_CreatedDate DEFAULT (GETDATE())
	,UpdatedDate			DATETIME CONSTRAINT DF_crmConversationGroup_UpdatedDate DEFAULT (GETDATE())
	,LanguageId             INT
	,Remark                 NVARCHAR(2000)
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
	,BotId	INT NOT NULL
	,CONSTRAINT PK_crmConversationGroupBot PRIMARY KEY CLUSTERED
	(
		ConversationGroupId ASC
		,BotId	ASC
	)
) ON DataChatBot
GO


CREATE TABLE dbo.crmConversationGroupRecipient
(
	ConversationGroupId SMALLINT NOT NULL
	,RecipientId		INT NOT NULL
	,CONSTRAINT PK_crmConversationGroupRecipient PRIMARY KEY CLUSTERED
	(
		ConversationGroupId ASC
		,RecipientId	ASC
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
		,HeadlineId	ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationRecipient
(
	NotificationId	INT NOT NULL
	,RecipientId	INT NOT NULL
	,ConversationGroupId SMALLINT
	,CONSTRAINT PK_crmNotificationRecipient PRIMARY KEY CLUSTERED
	(
		NotificationId ASC
		,RecipientId   ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationHeadline
(
	NotificationId	INT NOT NULL
	,HeadlineId		INT NOT NULL
	,CONSTRAINT PK_crmNotificationHeadline PRIMARY KEY CLUSTERED
	(
		NotificationId ASC
		,HeadlineId   ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmNotificationGroup
(
	NotificationId INT NOT NULL
	,ConversationGroupId SMALLINT NOT NULL
	,[Status] VARCHAR(20)
	,Reason NVARCHAR(MAX)
	,RetryTime TINYINT CONSTRAINT DF_crmNotificationGroup_RetryTime DEFAULT ((0))
	,CONSTRAINT PK_crmNotificationError PRIMARY KEY CLUSTERED
	(
		NotificationId ASC
	)
) ON DataChatBot
GO

CREATE TABLE dbo.crmJobException
(
	RequestId INT NOT NULL
	,ServiceName VARCHAR(100) NOT NULL
	,CreatedDate DATETIME CONSTRAINT DF_crmException_CreatedDate DEFAULT (GETDATE())
	,CONSTRAINT PK_crmException PRIMARY KEY CLUSTERED
	(
		RequestId ASC
		,ServiceName ASC
	)
) ON DataChatBot
GO

CREATE NONCLUSTERED INDEX IX_ChatBotProcessed ON dbo.crmMessageImport (IsChatBotProcessed)
GO