/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/

DECLARE @NotificationTemplateID INT, @NotificationTypeID INT, @EN INT, @SC INT, @EN_SC INT, @TH INT, @YN INT

SELECT @NotificationTypeID = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Result Amendment Announcement'

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
VALUES --Result Amendment Template - Sportsbook
('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
-- Result Amendment Template - Virtual Sports 2
,('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
-- Result Amendment Template - Virtual Sports
,('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
--Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)
,('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
--Result Amendment Template - Outright
,('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
--Accouting Pic Result Amendment Template - Sportsbook
('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
-- Accouting Pic  Result Amendment Template - Virtual Sports 2
,('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
-- Accouting Pic  Result Amendment Template - Virtual Sports
,('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
-- Accouting Pic Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)
,('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')
--Accouting Pic  Result Amendment Template - Outright
,('Result Amendment Template - Sportsbook', @EN, N'')
,('Result Amendment Template - Sportsbook', @SC,N'')
,('Result Amendment Template - Sportsbook', @EN_SC, N'')
,('Result Amendment Template - Sportsbook', @TH, N'')
,('Result Amendment Template - Sportsbook', @YN, N'')


INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
SELECT nt.NotificationTemplateId, c.LanguageId, c.Value
FROM @Contents c
	INNER JOIN dbo.crmNotificationTemplate nt WITH(NOLOCK) ON nt.NotificationTemplateName = c.NotificationTemplateName 

/* Add required params */

SELECT @NotificationTypeID = NotificationTypeId
FROM crmNotificationType WITH(NOLOCK)
WHERE NotificationTypeName  = 'Result Amendment Announcement'


DECLARE @NotificationTemplateID_SB INT
		,@NotificationTemplateID_VS2 INT
		,@NotificationTemplateID_VS	INT
		,@NotificationTemplateID_NG	INT
		,@NotificationTemplateID_OR	INT
		,@NotificationTemplateID_OR_AccPic INT


SELECT 
	@NotificationTemplateID_SB = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Sportsbook' THEN NotificationTemplateId ELSE @NotificationTemplateID_SB END
	,@NotificationTemplateID_VS2 = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Virtual Sports 2' THEN NotificationTemplateId ELSE @NotificationTemplateID_VS2 END
	,@NotificationTemplateID_VS = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Virtual Sports' THEN NotificationTemplateId ELSE @NotificationTemplateID_VS END
	,@NotificationTemplateID_NG = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)' THEN NotificationTemplateId ELSE @NotificationTemplateID_NG END
	,@NotificationTemplateID_OR = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Outright' THEN NotificationTemplateId ELSE @NotificationTemplateID_OR END
	,@NotificationTemplateID_OR_AccPic = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Accounting PIC' THEN NotificationTemplateId ELSE @NotificationTemplateID_OR_AccPic END
FROM crmNotificationTemplate WITH(NOLOCK)
WHERE NotificationTypeId = @NotificationTypeID

DECLARE @XML VARCHAR(MAX) = 
N'<root>
<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_SB AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="1">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{league_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{date}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="3" NotificationTemplateID="' + CAST(@NotificationTemplateID_VS2	 AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="2">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{date}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{round_match_info}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{round_match_info}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="101" NotificationTemplateID="' + CAST(@NotificationTemplateID_VS AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="3">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50004" Frequency="1"/>	
	</r>
	<r IsTest="0" GroupIds="0" LevelIds="102" NotificationTemplateID="' + CAST(@NotificationTemplateID_NG AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="4">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_th}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_yn}" LanguageId="50004" Frequency="2"/>
		
		<TemplateRequiredParam Value="{match_code}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{match_code}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{match_code}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{match_code}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{match_code}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{date}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50004" Frequency="1"/>	
		
		
	</r>
	<r IsTest="0" GroupIds="17" LevelIds="1" NotificationTemplateID="' + CAST(@NotificationTemplateID_OR AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="5">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_yn}" LanguageId="50004" Frequency="1"/>
		
	</r>
	<r IsTest="0" GroupIds="18" LevelIds="3" NotificationTemplateID="' + CAST(@NotificationTemplateID_OR_AccPic AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="105">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50000" Frequency="1"/>
	</r>
</root>'

UPDATE s
	SET s.Value = @XML
FROM dbo.SystemSetting s WITH (ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName  = 'NotificationTemplate'




