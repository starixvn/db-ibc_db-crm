/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20211125@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Chatbot for CRM - Initialize data [RedmineId : #163833]
*/
USE bodb_CRM
GO

DECLARE @SystemId INT, @NotificationTypeId INT, @RecipientTypeId INT, @NotificationTemplateId INT
	,@EN INT, @SC INT, @EN_SC INT, @TH INT, @YN INT, @LastLogID BIGINT

/* Insert a new notification type */
SELECT @SystemId = s.SystemId FROM dbo.crmSystem s WITH(NOLOCK) WHERE s.SystemName = 'Special Delete Site'

SELECT @NotificationTypeId = NotificationTypeId FROM dbo.crmNotificationType WHERE NotificationTypeName = 'Voiding Abnormal Bet Announcement' AND SystemId = @SystemId
/* Insert a new notification template */
INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES ('Voiding Abnormal Bet - Mix Parlay Template', @NotificationTypeId, 'Voiding Abnormal Bet - Mix Parlay Templat')

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
VALUES ('Voiding Abnormal Bet - Mix Parlay Template', @EN, N'Dear Sir, Customer service would like to inform that your member have abnormal bet, affected ticket has been VOIDED. Thank you. 

{EN Announcement} 

Kindly refer to Agency site "Cancelled Bets" for Voided user.

Affected user: {Affected List}')
,('Voiding Abnormal Bet - Mix Parlay Template', @SC,N'您好, 客服部在此通知您, 公司发现您旗下会员有非正常投注. 注單已被作廢. 謝謝! 

{SC Announcement} 

请浏览代理网 “已删除/作废注单” 查询有关作废账号。 

受影响会员: {Affected List}')
,('Voiding Abnormal Bet - Mix Parlay Template', @EN_SC, N'Dear Sir, Customer service would like to inform that your member have abnormal bet, affected ticket has been VOIDED. Thank you. 

{EN Announcement} 

Kindly refer to Agency site ""Cancelled Bets"" for Voided user. 

您好, 客服部在此通知您, 公司发现您旗下会员有非正常投注. 注單已被作廢. 謝謝! 

{SC Announcement}

请浏览代理网 “已删除/作废注单” 查询有关作废账号。

Affected user/受影响会员: {Affected List}')
,('Voiding Abnormal Bet - Mix Parlay Template', @TH, N'สวัสดีค่ะ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่าสมาชิกของคุณมีการเดิมพันที่ผิดปกติ ตั๋วเดิมพันที่ได้รับผลกระทบจึงเป็นโมฆะ  ขอบคุณค่ะ

{TH Announcement}

ข้อมูลเพิ่มเติมสำหรับตั๋วของสมาชิกที่เป็นโมฆะสามารถเช็คได้จากเว็บไซต์ตัวแทน "ยกเลิกการวางเดิมพัน"

บัญชีสมาชิกที่ได้รับผลกระทบ: {Affected List}')
,('Voiding Abnormal Bet - Mix Parlay Template', @YN, N'Xin chào, bộ phận Dịch vụ Khách hàng của chúng tôi xin thông báo rằng thành viên của bạn có cá cược bất thường, do đó vé cược đã bị vô hiệu hoá. Xin cảm ơn.

{YN Announcement}

Vui lòng tham khảo thông tin bổ sung tại mục "Cược bị huỷ" trên trang web đại lý cho phần "Vô hiệu hoá".

Danh sách khách hàng: {Affected List}')


INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
SELECT nt.NotificationTemplateId, c.LanguageId, c.Value
FROM @Contents c
	INNER JOIN dbo.crmNotificationTemplate nt WITH(NOLOCK) ON nt.NotificationTemplateName = c.NotificationTemplateName 

/* Add required params */

DECLARE @NotificationTemplateID_AbnormalBets        INT
		,@NotificationTemplateID_AbnormalAccounts	INT
	    ,@NotificationTypeID_AbnormalBets           INT
		,@NotificationTypeID_AbnormalAccounts	    INT
		,@NotificationTemplateID_Parlay				INT
		,@NotificationTypeID_Parlay					INT

SELECT 
	@NotificationTemplateID_AbnormalBets = CASE WHEN  NotificationTemplateName = 'Voiding Abnormal Bet Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_AbnormalBets END
	,@NotificationTemplateID_AbnormalAccounts = CASE WHEN  NotificationTemplateName = 'Voiding Abnormal Account Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_AbnormalAccounts END
	,@NotificationTemplateID_Parlay = CASE WHEN  NotificationTemplateName = 'Voiding Abnormal Bet - Mix Parlay Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Parlay END
FROM crmNotificationTemplate WITH(NOLOCK)

SELECT 
	@NotificationTypeID_AbnormalBets = CASE WHEN  NotificationTypeName = 'Voiding Abnormal Bet Announcement ' THEN NotificationTypeId ELSE @NotificationTypeID_AbnormalBets END
	,@NotificationTypeID_AbnormalAccounts = CASE WHEN  NotificationTypeName = 'Voiding Abnormal Account Announcement' THEN NotificationTypeId ELSE @NotificationTypeID_AbnormalAccounts END
	,@NotificationTypeID_Parlay = CASE WHEN  NotificationTypeName = 'Voiding Abnormal Bet Announcement' THEN NotificationTypeId ELSE @NotificationTypeID_Parlay END
FROM crmNotificationType WITH(NOLOCK)

DECLARE @XML VARCHAR(MAX) = 
		N'<root>
			<r IsTest="0" NotificationTemplateID="'+ CONVERT(VARCHAR(20), @NotificationTemplateID_AbnormalBets)+'" NotificationTypeID="' + CONVERT(VARCHAR(20),@NotificationTypeID_AbnormalBets) +'" Type="1">
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50000" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50001" />
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{TH Announcement}" LanguageId="50003" />
				<TemplateRequiredParam Value="{YN Announcement}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50000" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50001" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50003" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50002" />
			</r>
			<r IsTest="0" NotificationTemplateID="'+ CONVERT(VARCHAR(20), @NotificationTemplateID_AbnormalAccounts)+'" NotificationTypeID="' + CONVERT(VARCHAR(20),@NotificationTypeID_AbnormalAccounts) +'" Type="2">
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50000" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50001" />
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{TH Announcement}" LanguageId="50003" />
				<TemplateRequiredParam Value="{YN Announcement}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50000" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50001" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50003" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50002" />
			</r>
			<r IsTest="0" NotificationTemplateID="'+ CONVERT(VARCHAR(20), @NotificationTemplateID_Parlay)+'" NotificationTypeID="' + CONVERT(VARCHAR(20),@NotificationTypeID_Parlay) +'" Type="3">
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50000" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50001" />
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{TH Announcement}" LanguageId="50003" />
				<TemplateRequiredParam Value="{YN Announcement}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50000" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50001" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50003" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50002" />
			</r>
		</root> '
UPDATE s
	SET s.Value = @XML
FROM dbo.SystemSetting s WITH (ROWLOCK)
WHERE ServiceName = 'ChatBot - AbnormalBets' AND SettingName  = 'NotificationTemplate'


