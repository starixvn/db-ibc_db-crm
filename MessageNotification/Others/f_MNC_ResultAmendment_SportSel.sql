/*<info serverAlias="DBCRM-MessageNotification" selecters="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_MNC_ResultAmendment_SportSel]
	(@SportType	SMALLINT = NULL,
    @Environment VARCHAR(10) = 'LIVE')
RETURNS TABLE
AS
/*
	Created: 20241101@Tacy
	Task : Sports applied Result Amendment
	DB: DBCRM-MessageNotification

	Revisions:
		- 20241101@Tacy: Initial Func [RedmineID: #212035]
		- 20250417@Dave: MNC - for Result Amendment of Tennis, Table Tennis, Badminton & Volleyball - Return column SuffixRefID [RedmineID: #218014]
		- 20250916@Dave: MNC - Auto Result Amendment for Fast Market [RedmineID: #230646]

	Param's Explanation::		
*/	
RETURN
	SELECT s.SportType, REPLACE(s.SportName,'-','') AS SportName,
	CASE s.SportType 
		WHEN 45 THEN 'BeachVol'
		ELSE REPLACE(REPLACE(s.SportName,' ',''),'-','')
	END AS SuffixRefID
	FROM bodb02.dbo.Sports s WITH(NOLOCK)
	WHERE (s.SportType=@SportType OR @SportType IS NULL)
	AND EXISTS (
		SELECT TOP(1) 1
		FROM dbo.f_NotiTemplateMapping_Sel(s.SportType, NULL, NULL, @Environment)
	)
