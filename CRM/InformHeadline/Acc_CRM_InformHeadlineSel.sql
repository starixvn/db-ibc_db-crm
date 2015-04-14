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
	
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY, GroupID INT)	
	INSERT INTO #DirectAcc (CustID, GroupID)
	SELECT CustID, GroupID FROM bodb02.dbo.f_InformHeadlineList (@Currency, @Level, @Site, @TypeAccount) 	

	IF @ItemsPerPage = -1 -- Export excel purpose
		SELECT	ID, HeadlineID, username, GroupID,
				45006 AS InformHeadlineStatusID			
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY hl.GroupID DESC, c.username) AS ID,
						hl.CustID AS HeadlineID, 
						c.username,
						hl.GroupID
				FROM #DirectAcc hl
					INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON hl.CustID = c.custid		
				)tmp
	ELSE
		SELECT	ID, HeadlineID, username, GroupID,
				45006 AS InformHeadlineStatusID			
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY hl.GroupID DESC, c.username) AS ID,
						hl.CustID AS HeadlineID, 
						c.username,
						hl.GroupID
				FROM #DirectAcc hl
					INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON hl.CustID = c.custid		
				)tmp
		WHERE ID BETWEEN @PageIndex*@ItemsPerPage-@ItemsPerPage+1 AND @PageIndex*@ItemsPerPage

	DROP TABLE #DirectAcc 	
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSel] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineSel] TO [vnteam]