/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName)
VALUES ('ServiceFlag', '1', 'ChatBot - ResultAmendment')
	,('SubmitDate', '2021-07-31', 'ChatBot - ResultAmendment')
	,('Seq', '0', 'ChatBot - ResultAmendment')
	,('LastLogIdUAT', '0', 'ChatBot - ResultAmendment')
	,('IncludeUUSCurrency', '1', 'ChatBot - ResultAmendment')
	,('BatchSize', '3000', 'ChatBot - ResultAmendment')
	,('JobStatus', 'Completed', 'ChatBot - ResultAmendment')
	,('JobStatusUAT', 'Completed', 'ChatBot - ResultAmendment')
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
VALUES ('Problem Account Marked Template', @NotificationTypeID, 'Problem Account Marked Template')

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES 
	('Result Amendment Template - Sportsbook', @NotificationTypeID, 'Result Amendment Template - Sportsbook')
	,('Result Amendment Template - Virtual Sports 2', @NotificationTypeID, 'Result Amendment Template - Virtual Sports 2')
	,('Result Amendment Template - Virtual Sports', @NotificationTypeID, 'Result Amendment Template - Virtual Sports')
	,('Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @NotificationTypeID, 'Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)')
	,('Result Amendment Template - Outright', @NotificationTypeID, 'Result Amendment Template - Outright')
	,('Result Amendment Template - Accounting PIC', @NotificationTypeID, 'Result Amendment Template - Accounting PIC')

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
,('Company Win Loss Limit - Red Level Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo có [Người Thắng Lớn] trong hệ thống của quý khách. Tên đăng nhập của thành viên là  "{player_username}", hiện tại số tiền thắng đã lên tới "{player_wl_amount} ({player_currency})" trong "{product_name_yn}". Xin vui lòng lưu ý, cám ơn quý khách!')

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
,('Company Win Loss Limit - Black Level Template', @TH, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่า สมาชิก "{player_username}" ขณะนี้มียอดเสีย [ถึงขีดจำกัดจำนวนเงินที่เสียสูงสุด] คือ "{player_wl_amount} ({player_currency})" ใน {product_name_th} จึงเรียนมาเพื่อทราบ ขอบคุณค่ะ')
,('Company Win Loss Limit - Black Level Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin quý khách lưu ý tới thành viên "{player_username}", đã đạt giới hạn thua tối đa lên tới "{player_wl_amount} ({player_currency})" trong {product_name_yn}. Xin cám ơn quý khách đã lưu tâm!')

--
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @EN, N'Dear Sir, Customer Support would like to inform that member "{player_username}", has currently won the Jackpot amount of "{player_wl_amount} ({player_currency})" in RNG Casino Baccarat Progressive Jackpot. Thank you for your kind attention!')
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @SC, N'您好，客服部在此通知 会员 "{player_username}" 目前在 娱乐城赢了百家乐聚宝奖金 为 "{player_wl_amount} ({player_currency})"。 谢谢您的关注与支持!')
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @EN_SC, N'Dear Sir, Customer Support would like to inform that member "{player_username}", has currently won the Jackpot amount of "{player_wl_amount} ({player_currency})" in RNG Casino Baccarat Progressive Jackpot. Thank you for your kind attention!

您好，客服部在此通知 会员 "{player_username}" 目前在 娱乐城赢了百家乐聚宝奖金 为 "{player_wl_amount} ({player_currency})"。 谢谢您的关注与支持!')
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @TH, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่า สมาชิก "{player_username}" ขณะนี้ชนะรางวัล แจ็คพอต จำนวนเงิน "{player_wl_amount} ({player_currency})" ใน RNG คาสิโน Baccarat Progressive Jackpot ขอขอบคุณสำหรับความสนใจและการสนับสนุนของคุณ')
,('Company Win Loss Limit - RNG Progressive Jackpot Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thành viên "{player_username}", hiện tại số tiền thắng tại Jackpot lên tới "{player_wl_amount} ({player_currency})" trong RNG Casino Baccarat Progressive Jackpot. Xin cám ơn quý khách!')


DECLARE @xml NVARCHAR(MAX) = ''

SELECT @xml = '<root>
					<r IsTest="0" NotificationTemplateID="'+ CONVERT(NVARCHAR(MAX), @NotificationTemplateID) +'" NotificationTypeID="'+ CONVERT(NVARCHAR(MAX), @NotificationTypeID) +'"> 
						<TemplateRequiredParam Value="{content_en}" LanguageId="50000" Frequency="1"/>
						<TemplateRequiredParam Value="{content_sc}" LanguageId="50001" Frequency="1"/>
						<TemplateRequiredParam Value="{content_en_sc}" LanguageId="50002" Frequency="1"/>
						<TemplateRequiredParam Value="{content_th}" LanguageId="50003" Frequency="1"/>
						<TemplateRequiredParam Value="{content_yn}" LanguageId="50004" Frequency="1"/>
					</r>
			  </root>'

UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = @xml
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName = 'NotificationTemplate'





