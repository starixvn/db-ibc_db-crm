/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
	Created: 20201021@Percy
	DB: DBCRM-bodb_CRM
	Task: Chatbot for CRM - Clean up testing data on UAT
*/

use bodb_CRM
go

truncate table dbo.crmConversationBot
go
truncate table dbo.crmConversationGroup
go
truncate table dbo.crmConversationGroupBot
go
truncate table dbo.crmConversationGroupHeadline
go
truncate table dbo.crmConversationGroupRecipient
go
truncate table dbo.crmNotification
go
truncate table dbo.crmNotificationGroup
go
truncate table dbo.crmNotificationHeadline
go
truncate table dbo.crmNotificationMsgLog
go
truncate table dbo.crmNotificationRecipient
go
truncate table dbo.crmNotificationChatType
go
truncate table dbo.crmNotificationRecipientType
go
truncate table dbo.crmNotificationTemplate
go
truncate table dbo.crmNotificationTemplateContent
go
truncate table dbo.crmNotificationType
go
truncate table dbo.crmRecipient
go
truncate table dbo.crmRecipientType
go

delete dbo.crmUserLog_RunSP with (rowlock, updlock)
where ActionId between 1001 and 1009

---------------
INSERT INTO dbo.crmRecipientType (RecipientTypeName)
VALUES ('PIC of headline')

INSERT INTO dbo.crmRecipient (RecipientTypeId, SourceId, DataSource)
SELECT 1, p.PicID, 'bodb_CRM.dbo.crmPIC'
FROM dbo.crmPIC p WITH(NOLOCK)

INSERT INTO dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES ('Voiding Abnormal Bet Announcement', 1)

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
VALUES (1, 1)

INSERT INTO dbo.crmNotificationChatType (NotificationTypeId, ChatTypeId)
VALUES (1, 1), (1, 2)

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES ('Voiding Abnormal Bet Template', 1, 'Voiding Abnormal Bet Template')

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
SELECT 1, LanguageId, Content
FROM @Content