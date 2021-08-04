/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/

DECLARE @NotificationTemplateID INT, @NotificationTypeID INT, @EN INT, @SC INT, @EN_SC INT, @TH INT, @YN INT

SELECT @NotificationTypeID = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Result Amendment Announcement'

SELECT @NotificationTypeID = NotificationTypeId
FROM crmNotificationType WITH(NOLOCK)
WHERE NotificationTypeName  = 'Result Amendment Announcement'


DECLARE @NotificationTemplateID_SB INT
		,@NotificationTemplateID_VS2 INT
		,@NotificationTemplateID_VS	INT
		,@NotificationTemplateID_NG	INT
		,@NotificationTemplateID_OR	INT
		,@NotificationTemplateID_SB_AccPic INT
		,@NotificationTemplateID_VS2_AccPic INT
		,@NotificationTemplateID_VS_AccPic	INT
		,@NotificationTemplateID_NG_AccPic	INT
		,@NotificationTemplateID_OR_AccPic INT


SELECT 
	@NotificationTemplateID_SB = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Sportsbook' THEN NotificationTemplateId ELSE @NotificationTemplateID_SB END
	,@NotificationTemplateID_VS2 = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Virtual Sports 2' THEN NotificationTemplateId ELSE @NotificationTemplateID_VS2 END
	,@NotificationTemplateID_VS = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Virtual Sports' THEN NotificationTemplateId ELSE @NotificationTemplateID_VS END
	,@NotificationTemplateID_NG = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)' THEN NotificationTemplateId ELSE @NotificationTemplateID_NG END
	,@NotificationTemplateID_OR = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Outright - Uncalc Template' THEN NotificationTemplateId ELSE @NotificationTemplateID_OR END
	,@NotificationTemplateID_SB_AccPic = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Accounting PIC
(Sportsbook)' THEN NotificationTemplateId ELSE @NotificationTemplateID_SB_AccPic END
	,@NotificationTemplateID_VS2_AccPic = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Accounting PIC
(Virtual Sports 2)' THEN NotificationTemplateId ELSE @NotificationTemplateID_VS2_AccPic END
	,@NotificationTemplateID_VS_AccPic = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Accounting PIC
(Virtual Sports)' THEN NotificationTemplateId ELSE @NotificationTemplateID_VS_AccPic END
	,@NotificationTemplateID_NG_AccPic = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Accounting PIC
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)' THEN NotificationTemplateId ELSE @NotificationTemplateID_NG_AccPic END
	,@NotificationTemplateID_OR_AccPic = CASE WHEN  NotificationTemplateName = 'Result Amendment Template - Accounting PIC
(Outright - Uncalc Template)' THEN NotificationTemplateId ELSE @NotificationTemplateID_OR_AccPic END
FROM crmNotificationTemplate WITH(NOLOCK)
WHERE NotificationTypeId = @NotificationTypeID

DECLARE @RecipientTypeHeadlinePic INT, @RecipientTypeAccoutingPic INT

SELECT @RecipientTypeAccoutingPic = CASE WHEN RecipientTypeName = 'Accounting PIC' THEN RecipientTypeId ELSE @RecipientTypeAccoutingPic END
 ,@RecipientTypeHeadlinePic = CASE WHEN RecipientTypeName = 'PIC of headline' THEN RecipientTypeId ELSE @RecipientTypeHeadlinePic END
FROM crmRecipientType WITH(NOLOCK)

DECLARE @XML VARCHAR(MAX) = 
'<root>
<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_SB AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="1" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeHeadlinePic)+'">
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
	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_VS2	 AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="2" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeHeadlinePic)+'">
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
		
		<TemplateRequiredParam Value="{round_match_info_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_yn}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{affected_list}" LanguageId="50004" Frequency="1"/>
	</r>
	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_VS AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="3" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeHeadlinePic)+'">
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
	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_NG AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="4" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeHeadlinePic)+'">
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
	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_OR AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="5" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeHeadlinePic)+'">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_th}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_yn}" LanguageId="50004" Frequency="1"/>
		
	</r>
	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_SB_AccPic AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="1" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeAccoutingPic)+'">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50004" Frequency="1"/>

		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50004" Frequency="1"/>

		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50004" Frequency="1"/>
		
		<TemplateRequiredParam Value="{league_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_sc}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_sc}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{league_name_sc}" LanguageId="50004" Frequency="1"/>

		<TemplateRequiredParam Value="{date}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50004" Frequency="2"/>
		
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50004" Frequency="2"/>
		
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50004" Frequency="2"/>
	</r>

	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_VS2_AccPic AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="2" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeAccoutingPic)+'">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50004" Frequency="1"/>

		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{home_name_sc}" LanguageId="50004" Frequency="1"/>

		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{away_name_sc}" LanguageId="50004" Frequency="1"/>

		<TemplateRequiredParam Value="{round_match_info_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_sc}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_sc}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_sc}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_sc}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{round_match_info_sc}" LanguageId="50004" Frequency="1"/>

		<TemplateRequiredParam Value="{date}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50004" Frequency="2"/>
		
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{actual_result}" LanguageId="50004" Frequency="2"/>
		
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{wrong_result}" LanguageId="50004" Frequency="2"/>
	</r>

	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_VS_AccPic AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="3" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeAccoutingPic)+'">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50000" Frequency="1"/>

		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>

		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>

		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50003" Frequency="1"/>

		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50004" Frequency="1"/>
	</r>

	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_NG_AccPic AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="4" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeAccoutingPic)+'">
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50004" Frequency="2"/>
		<TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50004" Frequency="2"/>

		<TemplateRequiredParam Value="{match_code}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{match_code}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{match_code}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{match_code}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{match_code}" LanguageId="50004" Frequency="2"/>

		<TemplateRequiredParam Value="{date}" LanguageId="50000" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50001" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50002" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50003" Frequency="2"/>
		<TemplateRequiredParam Value="{date}" LanguageId="50004" Frequency="2"/>
	</r>

	<r IsTest="0" NotificationTemplateID="' + CAST(@NotificationTemplateID_OR_AccPic AS VARCHAR(MAX)) +'" NotificationTypeID="' + CAST(@NotificationTypeID AS VARCHAR(MAX))+'" Type="5" RecipientTypeIds="'+ CONVERT(VARCHAR(MAX), @RecipientTypeAccoutingPic)+'">
		<TemplateRequiredParam Value="{message_content_en}" LanguageId="50000" Frequency="1"/>
		<TemplateRequiredParam Value="{message_content_sc}" LanguageId="50000" Frequency="1"/>

		<TemplateRequiredParam Value="{message_content_en}" LanguageId="50001" Frequency="1"/>
		<TemplateRequiredParam Value="{message_content_sc}" LanguageId="50001" Frequency="1"/>

		<TemplateRequiredParam Value="{message_content_en}" LanguageId="50002" Frequency="1"/>
		<TemplateRequiredParam Value="{message_content_sc}" LanguageId="50002" Frequency="1"/>

		<TemplateRequiredParam Value="{message_content_en}" LanguageId="50003" Frequency="1"/>
		<TemplateRequiredParam Value="{message_content_sc}" LanguageId="50003" Frequency="1"/>

		<TemplateRequiredParam Value="{message_content_en}" LanguageId="50004" Frequency="1"/>
		<TemplateRequiredParam Value="{message_content_sc}" LanguageId="50004" Frequency="1"/>
	</r>
</root>'

UPDATE s
	SET s.Value = @XML
FROM dbo.SystemSetting s WITH (ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName  = 'NotificationTemplate'




