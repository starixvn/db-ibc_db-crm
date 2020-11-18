/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201103@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Chatbot for CRM - Initialize data
*/
USE bodb_CRM
GO

DECLARE @SystemId INT, @NotificationTypeId INT, @RecipientTypeId INT, @NotificationTemplateId INT
	,@EN INT, @SC INT, @EN_SC INT, @TH INT, @YN INT

/*Add setting name = 'LastLogID'*/
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName)
VALUES ('LastLogID', '0', 'ChatBot - CWL'), 
	('BatchSize', '10', 'ChatBot - CWL'),
	('JobStatus', 'Completed', 'ChatBot - CWL'),
	('NotificationTemplate', '10', 'ChatBot - CWL'),
	('ServiceFlag', '1', 'ChatBot - CWL')

UPDATE n
	SET n.ReferenceId = n.MessageId
		,n.DataSource = 'MessageId'
FROM dbo.crmNotification n WITH(ROWLOCK)
WHERE n.MessageId IS NOT NULL

/* Insert a new notification type */
INSERT INTO dbo.crmSystem (SystemName)
VALUES ('Risk & Control')

SELECT @SystemId = SCOPE_IDENTITY()

INSERT INTO  dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES ('Comany Win Loss Limit Announcement', @SystemId)

SELECT @NotificationTypeId = SCOPE_IDENTITY()

SELECT @RecipientTypeId = RecipientTypeId FROM dbo.crmRecipientType WITH(NOLOCK) WHERE RecipientTypeName = 'PIC of headline'

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
VALUES (@NotificationTypeId, @RecipientTypeId)

INSERT INTO dbo.crmNotificationChatType(NotificationTypeId, ChatTypeId)
VALUES (@NotificationTypeId, 1), (@NotificationTypeId, 2)

/* Insert a new notification template */

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES ('Company Win Loss Limit - Orange/Yellow Level Template', @NotificationTypeId, 'Company Win Loss Limit - Orange/Yellow Level Template')
	,('Company Win Loss Limit - Red Level Template', @NotificationTypeId, 'Company Win Loss Limit - Red Level Template')
	,('Company Win Loss Limit - Grey Level Template', @NotificationTypeId, 'Company Win Loss Limit - Grey Level Template')
	,('Company Win Loss Limit - Black Level Template', @NotificationTypeId, 'Company Win Loss Limit - Black Level Template')
	,('Company Win Loss Limit - RNG Progressive Jackpot Template', @NotificationTypeId, 'Company Win Loss Limit - RNG Progressive Jackpot Template')


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
VALUES ('Company Win Loss Limit - Orange/Yellow Level Template', @EN, N'Dear Sir, Customer Support would like to inform that member "{player_username}", currently has won amounted to "{player_wl_amount} ({player_currency})" in {product_name_en}. Thank you for your kind attention!')
,('Company Win Loss Limit - Orange/Yellow Level Template', @SC,N'您好, 客服部在此通知 会员 "{player_username}" 目前在{product_name_sc} 赢了 "{player_wl_amount} ({player_currency})"。谢谢您的关注与支持!')
,('Company Win Loss Limit - Orange/Yellow Level Template', @EN_SC, N'Dear Sir, Customer Support would like to inform that member "{player_username}", currently has won amounted to "{player_wl_amount} ({player_currency})" in {product_name_en}. Thank you for your kind attention!

您好, 客服部在此通知 会员 "{player_username}" 目前在{product_name_sc} 赢了 "{player_wl_amount} ({player_currency})"。谢谢您的关注与支持!')
,('Company Win Loss Limit - Orange/Yellow Level Template', @TH, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่า สมาชิก "{player_username}" ขณะนี้มียอดชนะ "{player_wl_amount} ({player_currency})" ใน {product_name_th} ขอขอบคุณสำหรับความสนใจและการสนับสนุนของคุณ')
,('Company Win Loss Limit - Orange/Yellow Level Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thành viên "{player_username}", hiện tại số tiền thắng lên tới "{player_wl_amount} ({player_currency})" trong {product_name_yn}. Xin cám ơn quý khách!')

--
,('Company Win Loss Limit - Red Level Template', @EN, N'Dear Sir, Customer Support would like to inform that there is [BIG Winner] under your line. Member username is "{player_username}", currently has won amount of "{player_wl_amount} ({player_currency})" in "{product_name_en}". Kindly take note, thank you!')
,('Company Win Loss Limit - Red Level Template', @SC, N'您好，客服部在此通知 会员 "{player_username}" 目前已达到 [赢取金额上限] 数目为 "{player_wl_amount} ({player_currency})" 在 "{product_name_sc}". 请您留意 谢谢!')
,('Company Win Loss Limit - Red Level Template', @EN_SC, N'Dear Sir, Customer Support would like to inform that there is [BIG Winner] under your line. Member username is "{player_username}", currently has won amount of "{player_wl_amount} ({player_currency})" in "{product_name_en}". Kindly take note, thank you!

您好，客服部在此通知 会员 "{player_username}" 目前已达到 [赢取金额上限] 数目为 "{player_wl_amount} ({player_currency})" 在 "{product_name_sc}". 请您留意 谢谢!')
,('Company Win Loss Limit - Red Level Template', @TH, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่า สมาชิก "{player_username}" ขณะนี้มียอดชนะ [ถึงขีดจำกัดจำนวนเงินที่ชนะสูงสุด] คือ "{player_wl_amount} ({player_currency})" ใน"{product_name_th}" จึงเรียนมาเพื่อทราบ ขอบคุณค่ะ')
,('Company Win Loss Limit - Red Level Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo có [ Người Thắng Lớn ] trong hệ thống của quý khách. Tên đăng nhập của thành viên là  "{player_username}", hiện tại số tiền thắng đã lên tới "{player_wl_amount} ({player_currency})" trong {product_name_yn}. Xin vui lòng lưu ý, cám ơn quý khách!')

--
,('Company Win Loss Limit - Grey Level Template', @EN, N'Dear Sir, Customer Support would like to inform that member "{player_username}", currently has loss amounted to "{player_wl_amount} ({player_currency})" in {product_name_en}. Thank you for your kind attention!')
,('Company Win Loss Limit - Grey Level Template', @SC, N'您好, 客服部在此通知 会员 "{player_username}" 目前在{product_name_sc} 输了 "{player_wl_amount} ({player_currency})"。谢谢您的关注与支持!')
,('Company Win Loss Limit - Grey Level Template', @EN_SC, N'Dear Sir, Customer Support would like to inform that member "{player_username}", currently has loss amounted to "{player_wl_amount} ({player_currency})" in {product_name_en}. Thank you for your kind attention!

您好, 客服部在此通知 会员 "{player_username}" 目前在{product_name_sc} 输了 "{player_wl_amount} ({player_currency})"。谢谢您的关注与支持!')
,('Company Win Loss Limit - Grey Level Template', @TH, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่า สมาชิก "{player_username}" ขณะนี้มียอดเสีย "{player_wl_amount} ({player_currency})" ใน {product_name_th} ขอขอบคุณสำหรับความสนใจและการสนับสนุนของคุณ')
,('Company Win Loss Limit - Grey Level Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thành viên  "{player_username}", hiện tại số tiền thua lên tới "{player_wl_amount} ({player_currency})" trong {product_name_yn}. Xin cám ơn quý khách!')

--
,('Company Win Loss Limit - Black Level Template', @EN, N'Dear Sir, Customer Support would like to draw your attention towards member "{player_username}" has [hit Max Lose Limit] amounted to "{player_wl_amount} ({player_currency})" in {product_name_en}. Kindly take note, thank you!')
,('Company Win Loss Limit - Black Level Template', @SC, N'您好，客服部在此通知 会员 "{player_username}" 目前已达到 [最高输额上限] 数目为"{player_wl_amount} ({player_currency})" 在{product_name_sc}. 请您留意 谢谢!')
,('Company Win Loss Limit - Black Level Template', @EN_SC, N'Dear Sir, Customer Support would like to draw your attention towards member "{player_username}" has [hit Max Lose Limit] amounted to "{player_wl_amount} ({player_currency})" in {product_name_en}. Kindly take note, thank you!

您好，客服部在此通知 会员 "{player_username}" 目前已达到 [最高输额上限] 数目为"{player_wl_amount} ({player_currency})" 在{product_name_sc}. 请您留意 谢谢!')
,('Company Win Loss Limit - Black Level Template', @TH, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่า สมาชิก "{player_username}" ขณะนี้มียอดเสีย [ถึงขีดจำกัดจำนวนเงินที่เสียสูงสุด] คือ "{player_wl_amount} ({player_currency})" ใน"{product_name_th}" จึงเรียนมาเพื่อทราบ ขอบคุณค่ะ')
,('Company Win Loss Limit - Black Level Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin quý khách lưu ý tới thành viên "{player_username}", đã đạt giới hạn thua tối đa lên tới "{player_wl_amount} ({player_currency})" trong {product_name_yn}. Xin cám ơn quý khách đã lưu tâm!')

--
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @EN, N'Dear Sir, Customer Support would like to inform that member "{player_username}", has currently won the Jackpot amount of "{player_wl_amount} ({player_currency})" in RNG Casino Baccarat Progressive Jackpot. Thank you for your kind attention!')
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @SC, N'您好，客服部在此通知 会员 "{player_username}" 目前在 娱乐城赢了百家乐聚宝奖金 为 "{player_wl_amount} ({player_currency})"。 谢谢您的关注与支持!')
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @EN_SC, N'Dear Sir, Customer Support would like to inform that member "{player_username}", has currently won the Jackpot amount of "{player_wl_amount} ({player_currency})" in RNG Casino Baccarat Progressive Jackpot. Thank you for your kind attention!

您好，客服部在此通知 会员 "{player_username}" 目前在 娱乐城赢了百家乐聚宝奖金 为 "{player_wl_amount} ({player_currency})"。 谢谢您的关注与支持!')
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @TH, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่า สมาชิก "{player_username}" ขณะนี้ชนะรางวัล แจ็คพอต จำนวนเงิน "{player_wl_amount} ({player_currency})" ใน RNG คาสิโน Baccarat Progressive Jackpot ขอขอบคุณสำหรับความสนใจและการสนับสนุนของคุณ')
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thành viên "{player_username}", hiện tại số tiền thắng tại Jackpot lên tới "{player_wl_amount} ({player_currency})" trong RNG Casino Baccarat Progressive Jackpot. Xin cám ơn quý khách!')


INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
SELECT nt.NotificationTemplateId, c.LanguageId, c.Value
FROM @Contents c
	INNER JOIN dbo.crmNotificationTemplate nt WITH(NOLOCK) ON nt.NotificationTemplateName = c.NotificationTemplateName 

/* Add required params */

SELECT @NotificationTypeID = NotificationTypeId
FROM crmNotificationType WITH(NOLOCK)
WHERE NotificationTypeName  = 'Comany Win Loss Limit Announcement'


DECLARE @NotificationTemplateID_Orange INT
		,@NotificationTemplateID_Red	INT
		,@NotificationTemplateID_Grey	INT
		,@NotificationTemplateID_Black	INT
		,@NotificationTemplateID_RNG	INT


SELECT 
	@NotificationTemplateID_Orange = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - Orange/Yellow Level Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Orange END
	,@NotificationTemplateID_Red = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - Red Level Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Red END
	,@NotificationTemplateID_Grey = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - Grey Level Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Grey END
	,@NotificationTemplateID_Black = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - Black Level Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Black END
	,@NotificationTemplateID_RNG = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - RNG Progressive Jackpot Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_RNG END
FROM crmNotificationTemplate WITH(NOLOCK)
WHERE NotificationTypeId = @NotificationTypeID

DECLARE @XML VARCHAR(MAX) = 
N'<root>
<r IsTest="0" GroupIds="0" LevelIds="1,2" NotificationTemplateID="' + CAST(@NotificationTemplateID_Orange AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" />
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" />
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" />
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" />
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" />
		<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" />
		<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" />
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="3" NotificationTemplateID="' + CAST(@NotificationTemplateID_Red	 AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" />
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" />
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" />
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" />
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" />
		<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" />
		<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" />
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="101" NotificationTemplateID="' + CAST(@NotificationTemplateID_Grey AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" />
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" />
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" />
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" />
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" />
		<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" />
		<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" />
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="102" NotificationTemplateID="' + CAST(@NotificationTemplateID_Black AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" />
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" />
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" />
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" />
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" />
		<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" />
		<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" />
	</r>
	<r IsTest="0" GroupIds="17,18" LevelIds="3" NotificationTemplateID="' + CAST(@NotificationTemplateID_RNG AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" />
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" />
	</r>
</root>'

UPDATE s
	SET s.Value = @XML
FROM dbo.SystemSetting s WITH (ROWLOCK)
WHERE ServiceName = 'ChatBot - CWL' AND SettingName  = 'NotificationTemplate'

