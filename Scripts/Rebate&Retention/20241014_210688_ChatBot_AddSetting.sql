/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20241014@Elodie
	DB: DBCRM/bodb_CRM
	Task: Insert data setting [RedmineId : #210688]
*/
USE bodb_CRM
GO

DECLARE @ServiceName VARCHAR(100) = 'ChatBot - RebateRetention',
		@NotificationTypeName NVARCHAR(500) = 'Reward Wallet Announcement',
		@SystemName VARCHAR(100) = 'NAP Accounting',
		@RecipientTypeName VARCHAR(200) = 'PIC of headline',
		@NotificationTemplateName NVARCHAR(1000) = 'Reward Wallet Announcement',
		@Title NVARCHAR(2000) = 'Reward Wallet Announcement';
		
DECLARE	@ContentEN NVARCHAR(MAX),@ContentSC NVARCHAR(MAX),@ContentEN_SC NVARCHAR(MAX), @ContentTH NVARCHAR(MAX), @ContentYN NVARCHAR(MAX), @xml NVARCHAR(MAX) = ''

SELECT	@ContentEN = N'Dear Sir,
Below is the list of Members who have received rewards from the company:
Super & Member: 
{Affected List}
The company is responsible for all relevant Reward amounts. Kindly refer to the "Reward Detail" for details and assist in distributing the funds to your downlines. 

Thank you for your kind attention!',
		@ContentSC = N'尊敬的先生，
 以下是获得公司奖励的会员名单：
 超级总代理和会员：
{Affected List}
 公司负责所有奖励金额。请参阅“奖励详情”了解详情，并协助将金额分配给您的下线。

 感谢您的关注！',
		@ContentEN_SC = N'Dear Sir,/尊敬的先生，
Below is the list of Members who have received rewards from the company:
以下是获得公司奖励的会员名单：
Super & Member: 
超级总代理和会员：
{Affected List}
The company is responsible for all relevant Reward amounts. Kindly refer to the "Reward Detail" for details and assist in distributing the funds to your downlines. 
公司负责所有奖励金额。请参阅“奖励详情”了解详情，并协助将金额分配给您的下线。

Thank you for your kind attention!
感谢您的关注！',
		@ContentTH = N'สวัสดีค่ะ
ด้านล่างนี้คือรายชื่อสมาชิกที่ได้รับรางวัลจากบริษัท:
ซุปเปอร์ & สมาชิก:
{Affected List}
บริษัทเป็นผู้รับผิดชอบจำนวนรางวัลทั้งหมด โปรดดูรายละเอียดใน "รายละเอียดรางวัล" และช่วยแจกจ่ายเงินให้กับดาวน์ไลน์ของคุณ

ขอขอบคุณค่ะ!',
		@ContentYN = N'Xin chào quý khách,
Dưới đây là danh sách các Member nhận tiền thưởng từ công ty:
Super & Member:
{Affected List}
Công ty sẽ chi trả toàn bộ số tiền thưởng này. Quý khách vui lòng xem thêm "Chi tiết tiền thưởng" để biết thêm thông tin và hỗ trợ phân phối tiền thưởng đến các cấp dưới của mình. 

Xin cảm ơn sự hợp tác của Quý khách!'

-- Starting LogSId
DECLARE @LastLogSId VARCHAR(MAX) = 
'<root>
	<r LastLogSID="0" SiteDBGroupId="3" ListPendingSIDs="" />
</root>';


INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName, DataType)
VALUES ('ServiceFlag', '1', @ServiceName, 'Boolean')
	,('LastLogSId', @LastLogSId, @ServiceName, 'XML')
	,('LastLogSIdUAT', @LastLogSId, @ServiceName, 'XML')
	,('IncludeUUSCurrency', '1', @ServiceName, 'Boolean')
	,('BatchSize', '1', @ServiceName, 'Int32')
	,('JobStatus', 'Completed', @ServiceName, 'String')
	,('JobStatusUAT', 'Completed', @ServiceName, 'String')
	,('NotificationTemplate', '', @ServiceName, 'String')
	,('LastRuntime', CONVERT(VARCHAR(50), GETDATE(), 120), @ServiceName, 'DateTime')
	,('LastRuntimeUAT', CONVERT(VARCHAR(50), GETDATE(), 120), @ServiceName, 'DateTime')
	
UPDATE s
SET s.Value = s.Value + ',' + @ServiceName
FROM SystemSetting s
WHERe SettingName = 'Services'

DECLARE @SystemId INT
DECLARE @NotificationTemplateID INT, @NotificationTypeID INT, @RecipientTypeId INT 

SELECT @SystemId = SystemId FROM crmSystem WHERE SystemName = @SystemName

INSERT INTO dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES (@NotificationTypeName, @SystemId)

SELECT @NotificationTypeID = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = @NotificationTypeName

SELECT @RecipientTypeId = RecipientTypeId FROM crmRecipientType WITH(NOLOCK) WHERE RecipientTypeName = @RecipientTypeName

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
VALUES (@NotificationTypeID, @RecipientTypeId)

INSERT INTO dbo.crmNotificationChatType (NotificationTypeId, ChatTypeId)
VALUES (@NotificationTypeId, 1), (@NotificationTypeId, 2)

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES (@NotificationTemplateName, @NotificationTypeID, @Title)

SELECT @NotificationTemplateID = NotificationTemplateId FROM dbo.crmNotificationTemplate WITH(NOLOCK) WHERE NotificationTemplateName = @NotificationTemplateName

INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
VALUES (@NotificationTemplateID, 50000, @ContentEN),
(@NotificationTemplateID, 50001, @ContentSC),
(@NotificationTemplateID, 50002, @ContentEN_SC)
,(@NotificationTemplateID, 50003, @ContentTH)
,(@NotificationTemplateID, 50004, @ContentYN)

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
WHERE ServiceName = @ServiceName AND SettingName = 'NotificationTemplate'





