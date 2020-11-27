/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201103@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update @IsTest = 1 [RedmineId : #144265]
*/

DECLARE @_XML NVARCHAR(MAX) = 
'<root> <r IsTest="1" NotificationTemplateID="1" NotificationTypeID="1">          <TemplateRequiredParam Value="{EN Announcement}" LanguageId="50000" />          <TemplateRequiredParam Value="{SC Announcement}" LanguageId="50001" />          <TemplateRequiredParam Value="{EN Announcement}" LanguageId="50002" />          <TemplateRequiredParam Value="{SC Announcement}" LanguageId="50002" />          <TemplateRequiredParam Value="{TH Announcement}" LanguageId="50003" />          <TemplateRequiredParam Value="{YN Announcement}" LanguageId="50004" />          <TemplateRequiredParam Value="{Affected List}" LanguageId="50000" />           <TemplateRequiredParam Value="{Affected List}" LanguageId="50001" />            <TemplateRequiredParam Value="{Affected List}" LanguageId="50003" />             <TemplateRequiredParam Value="{Affected List}" LanguageId="50004" />             <TemplateRequiredParam Value="{Affected List}" LanguageId="50002" /> </r>  </root>'

UPDATE s
	SET s.Value = @_XML
FROM dbo.SystemSetting s WITH (ROWLOCK)
WHERE ServiceName = 'ChatBot - AbnormalBets' AND SettingName  = 'NotificationTemplate'

DECLARE @NotificationTypeId INT
SELECT @NotificationTypeID = NotificationTypeId
FROM crmNotificationType WITH(NOLOCK)
WHERE NotificationTypeName  = 'Company Win Loss Limit Announcement'

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
<r IsTest="1" GroupIds="0" LevelIds="1,2" NotificationTemplateID="' + CAST(@NotificationTemplateID_Orange AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
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
	<r IsTest="1" GroupIds="0" LevelIds="3" NotificationTemplateID="' + CAST(@NotificationTemplateID_Red	 AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
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
	<r IsTest="1" GroupIds="0" LevelIds="101" NotificationTemplateID="' + CAST(@NotificationTemplateID_Grey AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
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
	<r IsTest="1" GroupIds="0" LevelIds="102" NotificationTemplateID="' + CAST(@NotificationTemplateID_Black AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
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
	<r IsTest="1" GroupIds="17" LevelIds="1" NotificationTemplateID="' + CAST(@NotificationTemplateID_RNG AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
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
	<r IsTest="1" GroupIds="18" LevelIds="3" NotificationTemplateID="' + CAST(@NotificationTemplateID_RNG AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'">
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