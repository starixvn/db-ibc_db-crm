/*<info serverAlias="DBCUST-CustDB" selecters="wsv_nap" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_GetWinLimit_Group_NormalList](
	@Environment VARCHAR(50)
)
RETURNS TABLE
AS
/*
	Created: 20250930@Dave
	Task: Get list of Normal Games's Seting Group that apply CWL notification
	DB: DBCUST/CustDB

	Revisions:
		- 20250929@Dave: CWL - Headline requests only trigger notifications under specific settings [RedmineId: #239736]
		
	Parameter's Explaination:
		- @Environment: 'LIVE' or 'UAT'
	Developer's Notes:
*/
RETURN

	SELECT GroupID, GroupName
	FROM dbo.WinLimit_Group WITH (NOLOCK)
	WHERE GroupName NOT LIKE '%Prize%'
		AND GroupName NOT LIKE '%Promotion%'
		AND GroupName NOT LIKE '%Tournament%'
		AND GroupName NOT LIKE '%Lucky Draw%'
		AND GroupName NOT IN ('Allbet Casino VIP');

GO
	
