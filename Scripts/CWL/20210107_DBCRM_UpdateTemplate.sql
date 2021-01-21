/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/
/*
Created: 20210107@Malcolm
Task : Insert template
DB: DBCRM/bodb_CRM	
*/

--Insert crmNotificationTemplate
DECLARE @Contents TABLE (NotificationTemplateName NVARCHAR(1000) , LanguageId INT, Value NVARCHAR(MAX))

DECLARE @EN INT, @SC INT, @EN_SC INT, @TH INT, @YN INT, @NotificationTypeId INT

SELECT @NotificationTypeID = NotificationTypeId
FROM crmNotificationType WITH(NOLOCK)
WHERE NotificationTypeName  = 'Company Win Loss Limit Announcement'

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES ('Company Win Loss Limit - PP Jackpot Template', @NotificationTypeID, 'Company Win Loss Limit - PP Jackpot Template')

SELECT 
	@EN		= CASE WHEN SettingValue = 'EN'		 THEN SettingID ELSE @EN	END,
	@SC		= CASE WHEN SettingValue = 'SC'		 THEN SettingID ELSE @SC	END,	
	@TH		= CASE WHEN SettingValue = 'TH'		 THEN SettingID ELSE @TH	END,
	@YN		= CASE WHEN SettingValue = 'YN'		 THEN SettingID ELSE @YN	END,
	@EN_SC	= CASE WHEN SettingValue = 'EN & SC' THEN SettingID ELSE @EN_SC END
FROM crmSetting WITH(NOLOCK)
WHERE SettingName = 'NotificationTemplateLanguage' AND IsActive = 1


INSERT INTO @Contents (NotificationTemplateName, LanguageId, Value)
VALUES ('Company Win Loss Limit - PP Jackpot Template', @EN, N'Dear Sir, Customer Support would like to inform that member "{player_username}", has currently won the Jackpot amount of "{player_wl_amount} ({player_currency})" in Pragmatic Play. Thank you for your kind attention!  ')
,('Company Win Loss Limit - PP Jackpot Template', @SC,N'您好，客服部在此通知 会员 "{player_username}" 目前在Pragmatic Play 赢了聚宝奖金为 “{player_wl_amount} ({player_currency})”。 谢谢您的关注与支持! ')
,('Company Win Loss Limit - PP Jackpot Template', @EN_SC, N'Dear Sir, Customer Support would like to inform that member "{player_username}", has currently won the Jackpot amount of "{player_wl_amount} ({player_currency})" in Pragmatic Play. Thank you for your kind attention!

您好，客服部在此通知 会员 "{player_username}" 目前在Pragmatic Play 赢了聚宝奖金为 “{player_wl_amount} ({player_currency})”。 谢谢您的关注与支持!')
,('Company Win Loss Limit - PP Jackpot Template', @TH, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่า สมาชิก "{player_username}" ขณะนี้ชนะรางวัล แจ็คพอต จำนวนเงิน "{player_wl_amount} ({player_currency})" ใน Pragmatic Play ขอขอบคุณสำหรับความสนใจและการสนับสนุนของคุณ')
,('Company Win Loss Limit - PP Jackpot Template', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thành viên "{player_username}", hiện tại số tiền thắng tại Jackpot lên tới "{player_wl_amount} ({player_currency})" trong Pragmatic Play. Xin cám ơn quý khách!')

INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
SELECT nt.NotificationTemplateId, c.LanguageId, c.Value
FROM @Contents c
	INNER JOIN dbo.crmNotificationTemplate nt WITH(NOLOCK) ON nt.NotificationTemplateName = c.NotificationTemplateName 


/* Add required params */


DECLARE @NotificationTemplateID_Orange	INT
		,@NotificationTemplateID_Red	INT
		,@NotificationTemplateID_Grey	INT
		,@NotificationTemplateID_Black	INT
		,@NotificationTemplateID_RNG	INT
		,@NotificationTemplateID_PP		INT


SELECT 
	@NotificationTemplateID_Orange = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - Orange/Yellow Level Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Orange END
	,@NotificationTemplateID_Red = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - Red Level Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Red END
	,@NotificationTemplateID_Grey = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - Grey Level Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Grey END
	,@NotificationTemplateID_Black = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - Black Level Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_Black END
	,@NotificationTemplateID_RNG = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - RNG Progressive Jackpot Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_RNG END
	,@NotificationTemplateID_PP = CASE WHEN  NotificationTemplateName = 'Company Win Loss Limit - PP Jackpot Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_PP END
FROM crmNotificationTemplate WITH(NOLOCK)
WHERE NotificationTypeId = @NotificationTypeID

DECLARE @XML VARCHAR(MAX) = 
N'<root>
<r IsTest="0" GroupIds="0" LevelIds="1,2" NotificationTemplateID="' + CAST(@NotificationTemplateID_Orange AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="3" NotificationTemplateID="' + CAST(@NotificationTemplateID_Red	 AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="101" NotificationTemplateID="' + CAST(@NotificationTemplateID_Grey AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="102" NotificationTemplateID="' + CAST(@NotificationTemplateID_Black AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" GroupIds="17" LevelIds="1" NotificationTemplateID="' + CAST(@NotificationTemplateID_RNG AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" GroupIds="18" LevelIds="3" NotificationTemplateID="' + CAST(@NotificationTemplateID_RNG AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" GroupIds="33" LevelIds="2" NotificationTemplateID="' + CAST(@NotificationTemplateID_PP AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
		<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
	</r>
</root>'

UPDATE s
	SET s.Value = @XML
FROM dbo.SystemSetting s WITH (ROWLOCK)
WHERE ServiceName = 'ChatBot - CWL' AND SettingName  = 'NotificationTemplate'
