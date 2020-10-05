/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20200810@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Chatbot for CRM - Initialize data
*/
USE bodb_CRM
GO

DECLARE @RecipientTypeId TINYINT, @SystemId TINYINT, @NotificationTypeId SMALLINT, @NotificationTemplateId SMALLINT

INSERT INTO dbo.crmRecipientType (RecipientTypeName)
VALUES ('PIC of headline')
SELECT @RecipientTypeId = SCOPE_IDENTITY()

INSERT INTO dbo.crmRecipient (RecipientTypeId, SourceId, DataSource)
SELECT @RecipientTypeId, p.PicID, 'bodb_CRM.dbo.crmPIC'
FROM dbo.crmPIC p WITH(NOLOCK)

INSERT INTO dbo.crmSystem (SystemName)
VALUES ('Special Delete Site')
SELECT @SystemId = SCOPE_IDENTITY()

INSERT INTO dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES ('Voiding Abnormal Bet Announcement', @SystemId)

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
VALUES (@NotificationTypeId, @RecipientTypeId)

INSERT INTO dbo.crmNotificationChatType (NotificationTypeId, ChatTypeId)
VALUES (@NotificationTypeId, 1), (@NotificationTypeId, 2)

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES ('Voiding Abnormal Bet Template', @NotificationTypeId, 'Voiding Abnormal Bet Template')
SELECT @NotificationTemplateId = SCOPE_IDENTITY()

DECLARE @Content TABLE (LanguageId INT, Content NVARCHAR(MAX))
INSERT INTO @Content (LanguageId, Content)
VALUES (50000, N'Dear Sir, Customer service would like to inform that your member have abnormal bet, affected ticket has been VOIDED. Thank you.

{EN Announcement}

Kindly refer to Agency site "Cancelled Bets" for Voided user.

Affected user: {Affected List}')
		,(50001, N'您好, 客服部在此通知您, 公司发现您旗下会员有非正常投注. 注單已被作廢. 謝謝!

{SC Announcement}

请浏览代理网 “已删除/作废注单” 查询有关作废账号。

受影响会员: {Affected List}')
		,(50002, N'Dear Sir, Customer service would like to inform that your member have abnormal bet, affected ticket has been VOIDED. Thank you.

{EN Announcement}

Kindly refer to Agency site "Cancelled Bets" for Voided user.

您好, 客服部在此通知您, 公司发现您旗下会员有非正常投注. 注單已被作廢. 謝謝!

{SC Announcement}

请浏览代理网 “已删除/作废注单” 查询有关作废账号。

Affected user/受影响会员: {Affected List}')
		,(50003, N'สวัสดีค่ะ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่าสมาชิกของคุณมีการเดิมพันที่ผิดปกติ ตั๋วเดิมพันที่ได้รับผลกระทบจึงเป็นโมฆะ  ขอบคุณค่ะ

{TH Announcement}

ข้อมูลเพิ่มเติมสำหรับตั๋วของสมาชิกที่เป็นโมฆะสามารถเช็คได้จากเว็บไซต์ตัวแทน "ยกเลิกการวางเดิมพัน"

บัญชีสมาชิกที่ได้รับผลกระทบ: {Affected List}')
		,(50004, N'Xin chào, bộ phận Dịch vụ Khách hàng của chúng tôi xin thông báo rằng thành viên của bạn có cá cược bất thường, do đó vé cược đã bị vô hiệu hoá. Xin cảm ơn.

{YN Announcement}

Vui lòng tham khảo thông tin bổ sung tại mục "Cược bị huỷ" trên trang web đại lý cho phần "Vô hiệu hoá".

Danh sách khách hàng: {Affected List}')

INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
SELECT @NotificationTemplateId, c.LanguageId, c.Content
FROM @Content c

INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName)
VALUES ('BatchSize', '10', 'ChatBot - AbnormalBets')
	,('JobStatus', 'Completed', 'ChatBot - AbnormalBets')
	,('NotificationTemplate', '<root> <r IsTest="0" NotificationTemplateID="1" NotificationTypeID="1">          <TemplateRequiredParam Value="{EN Announcement}" LanguageId="50000" />          <TemplateRequiredParam Value="{SC Announcement}" LanguageId="50001" />          <TemplateRequiredParam Value="{EN Announcement}" LanguageId="50002" />          <TemplateRequiredParam Value="{SC Announcement}" LanguageId="50002" />          <TemplateRequiredParam Value="{TH Announcement}" LanguageId="50003" />          <TemplateRequiredParam Value="{YN Announcement}" LanguageId="50004" />          <TemplateRequiredParam Value="{Affected List}" LanguageId="50000" />           <TemplateRequiredParam Value="{Affected List}" LanguageId="50001" />            <TemplateRequiredParam Value="{Affected List}" LanguageId="50003" />             <TemplateRequiredParam Value="{Affected List}" LanguageId="50004" />             <TemplateRequiredParam Value="{Affected List}" LanguageId="50002" /> </r>  </root>', 'ChatBot - AbnormalBets')
	,('ServiceFlag', '1', 'ChatBot - AbnormalBets')

-- 2015
UPDATE dbo.crmMessageImport WITH (ROWLOCK)
SET IsChatBotProcessed = 1