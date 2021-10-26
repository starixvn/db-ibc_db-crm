/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/

DECLARE @NotificationTemplateID INT, @NotificationTypeID INT, @EN INT, @SC INT, @EN_SC INT, @TH INT, @YN INT

SELECT @NotificationTypeID = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Result Amendment Announcement'

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES 
	('Result Amendment Template - No Result', @NotificationTypeID, 'Result Amendment Template - No Result')
	,('Result Amendment Template - Accounting PIC - No Result', @NotificationTypeID, 'Result Amendment Template - Accounting PIC - No Result')

DECLARE @Contents TABLE (NotificationTemplateName NVARCHAR(1000) , LanguageId INT, Value NVARCHAR(MAX))
SELECT 
	@EN		= CASE WHEN SettingValue = 'EN'		 THEN SettingID ELSE @EN	END,
	@SC		= CASE WHEN SettingValue = 'SC'		 THEN SettingID ELSE @SC	END,	
	@TH		= CASE WHEN SettingValue = 'TH'		 THEN SettingID ELSE @TH	END,
	@YN		= CASE WHEN SettingValue = 'YN'		 THEN SettingID ELSE @YN	END,
	@EN_SC	= CASE WHEN SettingValue = 'EN & SC' THEN SettingID ELSE @EN_SC END
FROM crmSetting WITH(NOLOCK)
WHERE SettingName = 'NotificationTemplateLanguage' AND IsActive = 1

INSERT INTO @Contents (NotificationTemplateName, LanguageId, Value)
VALUES --Result Amendment Template - No Result
('Result Amendment Template - No Result', @EN, N'Dear Sir, Customer Support would like to inform the below announcement:

{message_content_en}

Affected user: {affected_list}')
,('Result Amendment Template - No Result', @SC,N'您好，客服部在此通知以下的通告：

{message_content_sc}

受影响会员: {affected_list}')
,('Result Amendment Template - No Result', @EN_SC, N'Dear Sir, Customer Support would like to inform the below announcement:

{message_content_en}                     

您好，客服部在此通知以下的通告：

{message_content_sc}
   
Affected user/受影响会员: {affected_list}')
,('Result Amendment Template - No Result', @TH, N'เรียนลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบเกี่ยวกับประกาศด้านล่างนี้:

{message_content_th}

บัญชีสมาชิกที่ได้รับผลกระทบ: {affected_list}')
,('Result Amendment Template - No Result', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thông báo dưới đây:

{message_content_yn}

Tài khoản bị ảnh hưởng: {affected_list}')

--Result Amendment Template - Accounting PIC - No Result
,('Result Amendment Template - Accounting PIC - No Result', @EN, N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')
,('Result Amendment Template - Accounting PIC - No Result', @SC,N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')
,('Result Amendment Template - Accounting PIC - No Result', @EN_SC, N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')
,('Result Amendment Template - Accounting PIC - No Result', @TH, N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')
,('Result Amendment Template - Accounting PIC - No Result', @YN, N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')

INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
SELECT nt.NotificationTemplateId, c.LanguageId, c.Value
FROM @Contents c
	INNER JOIN dbo.crmNotificationTemplate nt WITH(NOLOCK) ON nt.NotificationTemplateName = c.NotificationTemplateName 

