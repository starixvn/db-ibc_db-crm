/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/
-- Add settings for ChatBot - ResultAmendment
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName)
VALUES ('ServiceFlag', '1', 'ChatBot - ResultAmendment')
	,('IncludeUUSCurrency', '1', 'ChatBot - ResultAmendment')
	,('BatchSize', '3000', 'ChatBot - ResultAmendment')
	,('BatchSizeGetMsg', '10', 'ChatBot - ResultAmendment')
	,('JobStatus', 'Completed', 'ChatBot - ResultAmendment')
	,('JobStatusUAT', 'Completed', 'ChatBot - ResultAmendment')
	,('SubmitDate', '2021-07-31', 'ChatBot - ResultAmendment')
	,('SubmitDateUAT', '2021-07-31', 'ChatBot - ResultAmendment')
	,('Seq', '0', 'ChatBot - ResultAmendment')
	,('SeqUAT', '0', 'ChatBot - ResultAmendment')
	,('NotificationTemplate', '', 'ChatBot - ResultAmendment')
	,('IsSyncSettingsForUAT', '1', 'ChatBot - ResultAmendment')

-- Add settings for ChatBot - ProblemAccounts
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName)
VALUES ('IsSyncSettingsForUAT', '1', 'ChatBot - ProblemAccounts')

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

