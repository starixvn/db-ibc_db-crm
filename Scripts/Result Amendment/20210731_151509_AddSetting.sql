/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName)
VALUES ('ServiceFlag', '1', 'ChatBot - ResultAmendment')
	,('IncludeUUSCurrency', '1', 'ChatBot - ResultAmendment')
	,('BatchSize', '3000', 'ChatBot - ResultAmendment')
	,('JobStatus', 'Completed', 'ChatBot - ResultAmendment')
	,('JobStatusUAT', 'Completed', 'ChatBot - ResultAmendment')
	,('SubmitDate', '2021-07-31', 'ChatBot - ResultAmendment')
	,('SubmitDateUAT', '2021-07-31', 'ChatBot - ResultAmendment')
	,('Seq', '0', 'ChatBot - ResultAmendment')
	,('SeqUAT', '0', 'ChatBot - ResultAmendment')
	,('NotificationTemplate', '', 'ChatBot - ResultAmendment')

DECLARE @SystemId INT
DECLARE @NotificationTemplateID INT, @NotificationTypeID INT, @EN INT, @SC INT, @EN_SC INT, @TH INT, @YN INT

INSERT INTO dbo.crmSystem (SystemName) VALUES ('NAP Accounting')

SELECT @SystemId = SystemId FROM crmSystem WHERE SystemName = 'NAP Accounting'

INSERT INTO dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES ('Result Amendment Announcement', @SystemId)

SELECT @NotificationTypeID = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Result Amendment Announcement'

DECLARE @RecipientType TABLE (RecipientTypeId TINYINT)
INSERT INTO @RecipientType (RecipientTypeId)
SELECT RecipientTypeId
FROM dbo.crmRecipientType WITH(NOLOCK)
WHERE RecipientTypeName IN ('PIC of headline', 'Accounting PIC')

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
SELECT @NotificationTypeID, RecipientTypeId
FROM @RecipientType

INSERT INTO dbo.crmNotificationChatType (NotificationTypeId, ChatTypeId)
VALUES (@NotificationTypeId, 1), (@NotificationTypeId, 2)

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES 
	('Result Amendment Template - Sportsbook', @NotificationTypeID, 'Result Amendment Template - Sportsbook')
	,('Result Amendment Template - Virtual Sports 2', @NotificationTypeID, 'Result Amendment Template - Virtual Sports 2')
	,('Result Amendment Template - Virtual Sports', @NotificationTypeID, 'Result Amendment Template - Virtual Sports')
	,('Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @NotificationTypeID, 'Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)')
	,('Result Amendment Template - Outright - Uncalc Template', @NotificationTypeID, 'Result Amendment Template - Outright - Uncalc Template')
	,('Result Amendment Template - Accounting PIC
(Sportsbook)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Sportsbook)')
	,('Result Amendment Template - Accounting PIC
(Virtual Sports 2)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Virtual Sports 2)')
	,('Result Amendment Template - Accounting PIC
(Virtual Sports)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Virtual Sports)')
	,('Result Amendment Template - Accounting PIC
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)')
	,('Result Amendment Template - Accounting PIC
(Outright - Uncalc Template)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Outright - Uncalc Template)')

