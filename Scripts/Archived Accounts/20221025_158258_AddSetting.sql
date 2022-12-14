/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221025@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #158258]
*/
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName, DataType)
VALUES ('ServiceFlag', '1', 'ChatBot - ArchivedAccounts', 'Boolean')
	,('LastLogID', '0', 'ChatBot - ArchivedAccounts', 'Int32')
	,('LastLogIdUAT', '0', 'ChatBot - ArchivedAccounts', 'Int32')
	,('IncludeUUSCurrency', '1', 'ChatBot - ArchivedAccounts', 'Boolean')
	,('BatchSize', '3000', 'ChatBot - ArchivedAccounts', 'Int32')
	,('JobStatus', 'Completed', 'ChatBot - ArchivedAccounts', 'String')
	,('JobStatusUAT', 'Completed', 'ChatBot - ArchivedAccounts', 'String')
	,('NotificationTemplate', '', 'ChatBot - ArchivedAccounts', 'String')
	,('LastRuntime', CONVERT(VARCHAR(50), GETDATE(), 120), 'ChatBot - ArchivedAccounts', 'DateTime')
	,('LastRuntimeUAT', CONVERT(VARCHAR(50), GETDATE(), 120), 'ChatBot - ArchivedAccounts', 'DateTime')
	,('IsSyncSettingsForUAT', '1', 'ChatBot - ArchivedAccounts', 'Boolean')
	
INSERT INTO SystemSetting (SettingName, Value, ServiceName,DataType)
VALUES ('Services', 'ChatBot - AbnormalBets,ChatBot - TOControl,ChatBot - CWL,ChatBot - ProblemAccounts,ChatBot - ResultAmendment,ChatBot - ArchivedAccounts', 'ChatBot - Settings', 'String')

DECLARE @SystemId INT
DECLARE @NotificationTemplateID INT, @NotificationTypeID INT, @RecipientType INT 

SELECT @SystemId = SystemId FROM crmSystem WHERE SystemName = 'Customer Management'

INSERT INTO dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES ('Dormant Account Announcement', @SystemId)

SELECT @NotificationTypeID = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Dormant Account Announcement'

SELECT @RecipientType = RecipientTypeId FROM crmRecipientType WITH(NOLOCK) WHERE RecipientTypeName = 'PIC of headline'

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
VALUES (@NotificationTypeID, @RecipientType)

INSERT INTO dbo.crmNotificationChatType (NotificationTypeId, ChatTypeId)
VALUES (@NotificationTypeId, 1), (@NotificationTypeId, 2)

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES ('Closed Unused Credit Accounts Notification', @NotificationTypeID, 'Closed Unused Credit Accounts Notification')

SELECT @NotificationTemplateID = NotificationTemplateId FROM dbo.crmNotificationTemplate WITH(NOLOCK) WHERE NotificationTemplateName = 'Closed Unused Credit Accounts Notification'

INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
VALUES (@NotificationTemplateID, 50000, 'Dear Sir, Customer Support would like to inform that some of your Super/Master/Agents were closed due to inactivity in the past 3 months. If you wish them to continue their business, you can reopen these accounts, otherwise you can take back their Given Credit. 1 month after being closed, these accounts will be disabled, and you will not be able to recover the given credit from them, which will result in a shortage of your total credit. 

*Gentle reminder: Please note that disabled accounts will not be restored.

Affected User:  {Affected List}

Thank you.'),
(@NotificationTemplateID, 50001, N'您好，客服部在此通知，由于您的一些超级总代理/总代理/代理已长达近三个月无活跃操作，因此账号已被关闭。倘若关闭账号持有者有意继续进行生意，您可重启账号，除此以外也可以取回该账号的信用额。账号将在关闭后的一个月被禁用。您将无法从这些账号取回信用额，这将导致您的信用额度不足。

*温馨提醒：请知悉，禁用后的账号将无法重启。

受影响的账号: {Affected List}

谢谢。'),
(@NotificationTemplateID, 50002,N'Dear Sir, Customer Support would like to inform that some of your Super/Master/Agents were closed due to inactivity in the past 3 months. If you wish them to continue their business, you can reopen these accounts, otherwise you can take back their Given Credit. 1 month after being closed, these accounts will be disabled, and you will not be able to recover the given credit from them, which will result in a shortage of your total credit. 

*Gentle reminder: Please note that disabled accounts will not be restored.


您好，客服部在此通知，由于您的一些超级总代理/总代理/代理已长达近三个月无活跃操作，因此账号已被关闭。倘若关闭账号持有者有意继续进行生意，您可重启账号，除此以外也可以取回该账号的信用额。账号将在关闭后的一个月被禁用。您将无法从这些账号取回信用额，这将导致您的信用额度不足。

*温馨提醒：请知悉，禁用后的账号将无法重启。

Affected Users / 受影响会员: {Affected List}

Thank you.

谢谢。')
,(@NotificationTemplateID, 50003, N'เรียน ลูกค้าที่เคารพ ขอแจ้งให้ทราบว่า ซุปเปอร์/มาสเตอร์/ เอเจนต์ บางส่วนของคุณถูกปิดเนื่องจากไม่มีการใช้งานในช่วง 3 เดือนที่ผ่านมา หากคุณต้องการให้พวกเขาทำธุรกิจต่อ คุณสามารถเปิดบัญชีเหล่านี้อีกครั้ง นอกจากนี้คุณยังสามารถนำยอดเครดิตของพวกเขากลับคืนมาได้เช่นกัน หนึ่งเดือนหลังจากถูกปิด บัญชีเหล่านี้จะถูกปิดใช้งานและคุณจะไม่สามารถเรียกคืนเครดิตจากบัญชีเหล่านี้ได้ซึ่งจะทำให้วงเงินเครดิตรวมของคุณไม่เพียงพอ

*โปรดทราบว่าบัญชีที่ถูกปิดใช้งานจะไม่สามารถกู้คืนได้

ชื่อผู้ใช้งานที่ได้รับผลกระทบ: {Affected List}

ขอบคุณค่ะ')
,(@NotificationTemplateID, 50004, N'Kính gửi quý khách, Bộ phận Hỗ trợ Khách hàng muốn thông báo rằng một số tài khoản Super / Master / Agents của quý khách đã bị đóng do không hoạt động trong 3 tháng qua. Nếu quý khách muốn họ tiếp tục kinh doanh, quý khách có thể mở lại các tài khoản này, nếu không quý khách có thể lấy lại Hạn mức tín dụng của họ. Một tháng sau khi bị đóng, các tài khoản này sẽ bị vô hiệu hóa và quý khách sẽ không thể khôi phục khoản Hạn mức tín dụng đã cho các tài khoản đó, điều này sẽ dẫn đến việc thiếu hụt tổng tín dụng của quý khách.

Xin được nhắc nhở: Xin lưu ý rằng các tài khoản bị vô hiệu hóa sẽ không thể khôi phục.

Người dùng bị ảnh hưởng: {Affected List}

Xin cám ơn quý khách!')

DECLARE @xml NVARCHAR(MAX) = ''

SELECT @xml = '<root>
					<r IsTest="0" NotificationTemplateID="'+ CONVERT(NVARCHAR(MAX), @NotificationTemplateID) +'" NotificationTypeID="'+ CONVERT(NVARCHAR(MAX), @NotificationTypeID) +'"> 
						<TemplateRequiredParam Value="{Affected List}" LanguageId="50000" Frequency="1"/>
						<TemplateRequiredParam Value="{Affected List}" LanguageId="50001" Frequency="1"/>
						<TemplateRequiredParam Value="{Affected List}" LanguageId="50002" Frequency="1"/>
						<TemplateRequiredParam Value="{Affected List}" LanguageId="50003" Frequency="1"/>
						<TemplateRequiredParam Value="{Affected List}" LanguageId="50004" Frequency="1"/>
					</r>
			  </root>'

UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = @xml
WHERE ServiceName = 'ChatBot - ArchivedAccounts' AND SettingName = 'NotificationTemplate'





