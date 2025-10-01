/*<info serverAlias="DBCRM-MessageNotification" selecters="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_NotiTemplateMapping_Sel]
(
	@SportType			SMALLINT
	,@NotificationType	TINYINT 	= NULL
	,@ActionType		TINYINT 	= NULL
	,@Environment		VARCHAR(10) = 'LIVE'
)
RETURNS TABLE
AS
/*
	Created: 20250916@Dave
	Task : Get mapping
	DB: DBCRM-MessageNotification

	Revisions:
		- 20250916@Dave: MNC - Auto Result Amendment for Fast Market [RedmineID: #230646]

	Param's Explanation::		
*/	
RETURN
	SELECT 
		tm.SportType, tm.TemplateID, tm.NotificationType, tm.ActionType, tm.MinAmended, tm.MaxAmended
	FROM 
		NotiTemplateMapping tm WITH (NOLOCK)
	WHERE (tm.SportType=@SportType OR @SportType IS NULL)
		AND (tm.NotificationType=@NotificationType OR @NotificationType IS NULL)
		AND (tm.ActionType=@ActionType OR @ActionType IS NULL)
	
	UNION ALL
	SELECT 
		tm_uat.SportType, tm_uat.TemplateID, tm_uat.NotificationType, tm_uat.ActionType, tm_uat.MinAmended, tm_uat.MaxAmended
	FROM 
		NotiTemplateMapping_uat tm_uat WITH (NOLOCK)
	WHERE @Environment = 'UAT'
		AND (tm_uat.SportType=@SportType OR @SportType IS NULL)
		AND (tm_uat.NotificationType=@NotificationType OR @NotificationType IS NULL)
		AND (tm_uat.ActionType=@ActionType OR @ActionType IS NULL)
