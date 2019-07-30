/*<info serverAlias="DBEXT-bodb02" selectors="bodbAdminNet" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_Inform_HeadlineList] (@Currency VARCHAR(1000), @Level VARCHAR(10), @Site VARCHAR(4000), @TypeAccount TINYINT)
RETURNS @DirectAcc TABLE (
	[CustID] [INT],
	[Username] VARCHAR(30),
	[GroupID] [INT] 
PRIMARY KEY CLUSTERED ([CustID])) 
AS 
/*	Created: Winnie
	Date: 20190729
	Task: Get Inform Headline
	DB: DBCRM/bodb_CRM
	Revisions:	
	
*/
BEGIN
	DECLARE @tmpCurrency TABLE (currency INT)	
	DECLARE @tmpLevel TABLE (roleID TINYINT)	
	DECLARE @tmpSite TABLE (Site VARCHAR(50))	

	INSERT INTO @tmpCurrency
	SELECT val
	FROM f_split (@Currency,',')

	INSERT INTO @tmpLevel
	SELECT val
	FROM f_split (@Level,',')

	IF EXISTS(SELECT TOP 1 1 FROM @tmpLevel WHERE roleID=0)
	BEGIN
		INSERT INTO @tmpLevel(roleID)
		SELECT 5
		UNION ALL
		SELECT 6
		UNION ALL
		SELECT 7
		UNION ALL
		SELECT 8
		UNION ALL
		SELECT 9
		UNION ALL
		SELECT 10
		DELETE FROM @tmpLevel WHERE roleID=0
	END
	INSERT INTO @tmpSite
	SELECT s.SiteName
	FROM f_split (@Site,',') v
		INNER JOIN dbo.crmSite s ON v.val = s.SiteID

	IF @TypeAccount = 1 OR @TypeAccount = 3
	BEGIN			
		INSERT INTO @DirectAcc (CustID, GroupID)	
		SELECT DISTINCT hl.custid, hl.groupID
		FROM bodb02.dbo.custAccount hl WITH (NOLOCK)  
			INNER JOIN bodb02.dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
			INNER JOIN bodb02.dbo.custInfo cih WITH (NOLOCK) ON hl.custid = cih.custid
			INNER JOIN @tmpLevel t ON ch.roleid= t.roleID
		WHERE hl.IsGroupHeadLine=1 AND
		(cih.closed=0 AND ISNULL(cih.reject,0) = 0 AND cih.Enabled = 1 AND ch.currency IN (SELECT currency FROM @tmpCurrency) AND ch.site IN (SELECT Site FROM @tmpSite))
	END

	IF @TypeAccount = 2 OR @TypeAccount = 3
	BEGIN	
		INSERT INTO @DirectAcc (CustID, GroupID)
		SELECT c.CustID, 0
		FROM bodb02.dbo.CustDirectAccount c WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.custInfo ci WITH (NOLOCK) ON c.custid = ci.custid			
			INNER JOIN bodb02.dbo.Customer co WITH (NOLOCK) ON co.custid = ci.custid				
			INNER JOIN @tmpLevel t ON ci.roleid=t.roleID		
		WHERE 
			co.currency IN (SELECT currency FROM @tmpCurrency) 
			AND co.site IN (SELECT Site FROM @tmpSite)
			AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1
			AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
	END		
	RETURN
END

