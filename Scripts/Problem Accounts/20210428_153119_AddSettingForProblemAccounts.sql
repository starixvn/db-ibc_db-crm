/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName)
VALUES ('ServiceFlag', '1', 'ChatBot - ProblemAccounts')
	,('LastLogID', '0', 'ChatBot - ProblemAccounts')
	,('LastLogIdUAT', '0', 'ChatBot - ProblemAccounts')
	,('IncludeUUSCurrency', '1', 'ChatBot - ProblemAccounts')
	,('BatchSize', '10', 'ChatBot - ProblemAccounts')
	,('JobStatus', 'Completed', 'ChatBot - ProblemAccounts')
	,('JobStatusUAT', 'Completed', 'ChatBot - ProblemAccounts')
	,('NotificationTemplate', '', 'ChatBot - ProblemAccounts')

DECLARE @SystemId INT
DECLARE @NotificationTemplateID INT, @NotificationTypeID INT, @RecipientType INT 

SELECT @SystemId = SystemId FROM crmSystem WHERE SystemName = 'Customer Management'

INSERT INTO dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES ('Problem Account Marked Announcement', @SystemId)

SELECT @NotificationTypeID = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Problem Account Marked Announcement'

SELECT @RecipientType = RecipientTypeId FROM crmRecipientType WITH(NOLOCK) WHERE RecipientTypeName = 'PIC of headline'

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
VALUES (@NotificationTypeID, @RecipientType)

INSERT INTO dbo.crmNotificationChatType (NotificationTypeId, ChatTypeId)
VALUES (@NotificationTypeId, 1), (@NotificationTypeId, 2)


INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES ('Problem Account Marked Template', @NotificationTypeID, 'Problem Account Marked Template')

SELECT @NotificationTemplateID = NotificationTemplateId FROM dbo.crmNotificationTemplate WITH(NOLOCK) WHERE NotificationTemplateName = 'Problem Account Marked Template'

INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
VALUES (@NotificationTemplateID, 50000, 'Dear Sir, Customer Support would like to inform the below announcement:

{content_en}

Thank you for your kind attention'),
(@NotificationTemplateID, 50001, N'您好，客服部在此通知以下的通告：

{content_sc}

谢谢您的关注与支持!'),
(@NotificationTemplateID, 50002,N'Dear Sir, Customer Support would like to inform the below announcement:

{content_en}

Thank you for your kind attention!    

您好，客服部在此通知以下的通告：

{content_sc}

谢谢您的关注与支持!')
,(@NotificationTemplateID, 50003, N'เรียนลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบเกี่ยวกับประกาศด้านล่างนี้:

{content_th}

คุณสำหรับความสนใจและการสนับสนุนของคุณ')
,(@NotificationTemplateID, 50004, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thông báo dưới đây:

{content_yn}

Xin cám ơn quý khách đã lưu tâm!')

DECLARE @xml NVARCHAR(MAX) = ''

SELECT @xml = '<root>
					<r IsTest="0" NotificationTemplateID="'+ CONVERT(NVARCHAR(MAX), @NotificationTemplateID) +'" NotificationTypeID="'+ CONVERT(NVARCHAR(MAX), @NotificationTypeID) +'"> 
						<TemplateRequiredParam Value="{content_en}" LanguageId="50000" Frequency="1"/>
						<TemplateRequiredParam Value="{content_sc}" LanguageId="50001" Frequency="1"/>
						<TemplateRequiredParam Value="{content_en}" LanguageId="50002" Frequency="1"/>
						<TemplateRequiredParam Value="{content_sc}" LanguageId="50002" Frequency="1"/>
						<TemplateRequiredParam Value="{content_th}" LanguageId="50003" Frequency="1"/>
						<TemplateRequiredParam Value="{content_yn}" LanguageId="50004" Frequency="1"/>
					</r>
			  </root>'

UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = @xml
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName = 'NotificationTemplate'





