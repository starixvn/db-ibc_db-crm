/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20200810@Malcolm
	Task : Create new table to Offer Telegram bot service [RedmineID : #179119]
	DB: DBCRM/bodb_CRM
	
*/
CREATE TABLE dbo.crmConversationPersonal(
	ConversationId			VARCHAR(200) NOT NULL,
	ChatTypeId				TINYINT NULL,
	Creator					INT NULL,
	CreatedDate				DATETIME NULL,
	UpdatedDate				DATETIME NULL,
	ChannelId				TINYINT NOT NULL,
	Username				VARCHAR(32) NOT NULL,
	CONSTRAINT PK_crmConversationPersonal PRIMARY KEY CLUSTERED 
	(
		ConversationId ASC, ChannelId ASC, Username ASC
	) ON DataChatBot
) ON DataChatBot
GO

CREATE TABLE [dbo].[crmConversationPersonalBot](
	ConversationId VARCHAR(200),
	ChannelId	TINYINT,
	BotId BIGINT NOT NULL,
 CONSTRAINT [PK_crmConversationPersonalBot] PRIMARY KEY CLUSTERED 
(
	ChannelId ASC,
	ConversationId ASC,
	BotId ASC
) ON [DataChatBot]
) ON [DataChatBot]
GO

CREATE NONCLUSTERED INDEX IX_Username ON dbo.crmConversationPersonal (Username)
ALTER TABLE dbo.crmConversationPersonal ADD  CONSTRAINT DF_crmConversationPersonal_CreatedDate  DEFAULT (getdate()) FOR CreatedDate
GO

ALTER TABLE dbo.crmConversationPersonal ADD  CONSTRAINT DF_crmConversationPersonal_UpdatedDate  DEFAULT (getdate()) FOR UpdatedDate
GO

CREATE TABLE dbo.crmChannel
(
	ChannelId TINYINT 
	,ChannelName NVARCHAR(100)
	,CONSTRAINT [PK_crmChannel] PRIMARY KEY CLUSTERED 
	(
		ChannelId ASC
	)
) ON [DataChatBot]
GO

INSERT INTO dbo.crmChannel (ChannelId, ChannelName)
VALUES (1, 'Letstalk'), (2, 'Telegram')
GO

ALTER TABLE dbo.crmNotification
ADD ChannelId TINYINT CONSTRAINT DF_crmNotification_ChannelId DEFAULT 1 
GO

ALTER TABLE dbo.crmConversationGroup
ADD ChannelId TINYINT CONSTRAINT DF_crmConversationGroup_ChannelId DEFAULT 1 
GO

ALTER TABLE dbo.crmConversationBot
ADD ChannelId TINYINT CONSTRAINT DF_crmConversationBot_ChannelId DEFAULT 1 
GO

UPDATE dbo.crmConversationGroup WITH(ROWLOCK, UPDLOCK)
SET ChannelId = 1
GO

UPDATE dbo.crmConversationBot WITH(ROWLOCK, UPDLOCK)
SET ChannelId = 1
GO

WHILE 1 = 1 
BEGIN
	UPDATE TOP(2000) dbo.crmNotification WITH(ROWLOCK, UPDLOCK)
		SET ChannelId = 1
	WHERE ChannelId IS NULL

	IF @@ROWCOUNT = 0
		BREAK
END
GO

ALTER TABLE dbo.crmConversationGroup
ADD Username VARCHAR(32) CONSTRAINT DF_crmConversationGroup_Username DEFAULT ''
GO

UPDATE dbo.crmConversationGroup
SET Username = ''
GO

ALTER TABLE crmConversationBot
DROP CONSTRAINT  PK_crmConversationBot
GO

ALTER TABLE crmConversationBot
ALTER COLUMN BotId BIGINT NOT NULL
GO

ALTER TABLE crmConversationBot
ALTER COLUMN ChannelId TINYINT NOT NULL
GO

ALTER TABLE  dbo.crmConversationBot
ADD CONSTRAINT PK_crmConversationBot PRIMARY KEY (BotId, ChannelId)
GO

ALTER TABLE crmConversationGroupBot
DROP CONSTRAINT  PK_crmConversationGroupBot
GO

ALTER TABLE crmConversationGroupBot
ALTER COLUMN BotId BIGINT NOT NULL
GO

ALTER TABLE  dbo.crmConversationGroupBot
ADD CONSTRAINT PK_crmConversationGroupBot PRIMARY KEY (ConversationGroupId, BotId)
GO

ALTER TABLE dbo.crmNotificationMsgLog
ALTER COLUMN BotId BIGINT
GO

