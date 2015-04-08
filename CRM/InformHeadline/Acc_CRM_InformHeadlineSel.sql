ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineSel]
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@PageIndex		INT = 1, 
	@ItemsPerPage	INT = 100,
	@ErrCode		INT	= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT	
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Select inform headline
	DB: DBCRM/bodb_CRM
		
	Revisions:

	Parameter's Explanation:				
		- @TypeAccount =1: Headline
						2: Direct account
						3: Both
	Example: EXEC Acc_CRM_InformHeadlineSel @Currency = '20,10,2', @Level = '3,4', @Site = 'BEST-ODDS,722222,222223', @TypeAccount = 3
*/
BEGIN
	SET NOCOUNT ON
	IF @Currency = '' OR @Level = '' OR @Site = ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'At least 1 option is selected.'
		RETURN
	END	

	DECLARE @tmpCurrency TABLE (currency INT)	
	DECLARE @tmpLevel TABLE (id INT IDENTITY(1,1), roleID INT)	
	DECLARE @tmpSite TABLE (Site VARCHAR(50))	
	CREATE TABLE #Headline (CustID INT PRIMARY KEY, GroupID INT)	
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY)

	INSERT INTO @tmpCurrency
	SELECT val
	FROM f_split (@Currency,',')

	INSERT INTO @tmpLevel
	SELECT val
	FROM f_split (@Level,',')

	INSERT INTO @tmpSite
	SELECT val
	FROM f_split (@Site,',')

	IF @TypeAccount = 1 OR @TypeAccount = 3
	BEGIN
	INSERT INTO #Headline (CustID, GroupID)
	SELECT DISTINCT hl.custid, hl.groupID
	FROM bodb02.dbo.custAccount hl WITH (NOLOCK)  
		INNER JOIN bodb02.dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
		INNER JOIN bodb02.dbo.CustInfo cih WITH (NOLOCK) ON ch.custid = cih.custid
		INNER JOIN bodb02.dbo.custAccount m WITH (NOLOCK) ON hl.groupID = m.groupID
		INNER JOIN bodb02.dbo.Customer cm WITH (NOLOCK) ON m.custid = cm.custid
		INNER JOIN bodb02.dbo.CustInfo cim WITH (NOLOCK) ON cm.custid = cim.custid
	WHERE hl.IsGroupHeadLine = 1 
		AND m.IsGroupHeadLine = 0 
		AND ch.roleid IN (SELECT roleID FROM @tmpLevel)
		AND (ch.currency IN (SELECT currency FROM @tmpCurrency) OR cm.currency IN (SELECT currency FROM @tmpCurrency)) 
		AND (ch.site IN (SELECT Site FROM @tmpSite) OR cm.site IN (SELECT Site FROM @tmpSite))
		AND ((cih.closed=0 AND ISNULL(cih.reject,0) = 0 AND cih.Enabled = 1) OR (cim.closed=0 AND ISNULL(cim.reject,0) = 0) AND cim.Enabled = 1)
		AND hl.groupID > 0
	END

	IF @TypeAccount = 2 OR @TypeAccount = 3
	BEGIN
		INSERT INTO #DirectAcc (CustID)
		SELECT c.CustID
		FROM bodb02.dbo.Customer c WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
		WHERE c.roleid IN (SELECT roleID FROM @tmpLevel)
			AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.Acc_CustDirect WITH (NOLOCK) WHERE custid = c.custid AND roleid IN (SELECT roleID FROM @tmpLevel))
			AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
			AND c.currency IN (SELECT currency FROM @tmpCurrency) 
			AND c.site IN (SELECT Site FROM @tmpSite)
			AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1
	END		

	IF @ItemsPerPage = -1 -- Export excel purpose
		SELECT	ID, HeadlineID, username, 
				45006 AS InformHeadlineStatusID			
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY c.username) AS ID,
						hl.CustID AS HeadlineID, 
						c.username
				FROM (
						SELECT CustID
						FROM #Headline
						UNION ALL 
						SELECT CustID
						FROM #DirectAcc
					)hl
					INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON hl.CustID = c.custid		
				)tmp
	ELSE
		SELECT	ID, HeadlineID, username, 
				45006 AS InformHeadlineStatusID			
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY c.username) AS ID,
						hl.CustID AS HeadlineID, 
						c.username
				FROM (
						SELECT CustID
						FROM #Headline
						UNION ALL 
						SELECT CustID
						FROM #DirectAcc
					)hl
					INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON hl.CustID = c.custid		
				)tmp
		WHERE ID BETWEEN @PageIndex*@ItemsPerPage-@ItemsPerPage+1 AND @PageIndex*@ItemsPerPage
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSel] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineSel] TO [vnteam]