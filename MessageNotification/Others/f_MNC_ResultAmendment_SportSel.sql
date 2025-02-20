/*<info serverAlias="DBCRM-MessageNotification" selecters="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_MNC_ResultAmendment_SportSel]
	(@SportType	SMALLINT = NULL)
RETURNS TABLE
AS
/*
	Created: 20241101@Tacy
	Task : Sports applied Result Amendment
	DB: DBCRM-MessageNotification

	Revisions:
		- 20241101@Tacy: Initial Func [RedmineID: #212035]

	Param's Explanation::		
*/	
RETURN
	SELECT s.SportType, REPLACE(s.SportName,'-','') AS SportName
	FROM bodb02.dbo.Sports s WITH(NOLOCK)
	CROSS APPLY (SELECT TOP 1 SportType
				 FROM NotiTemplateMapping tm
				 WHERE tm.SportType=s.SportType) t
	WHERE s.SportType=@SportType OR @SportType IS NULL
