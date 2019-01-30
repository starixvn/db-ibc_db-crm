/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE [bodb_CRM]
GO

ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineSel]
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@PageIndex		INT = 1, 
	@ItemsPerPage	INT = 100,
	@Ignored		BIT=0,
	@IsVip			BIT=0,
	@ErrCode		INT	= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT	
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Select inform headline
	DB: DBCRM/bodb_CRM
		
	Revisions:
		- 20160915@Winnie: Return  'Checker' and 'Ignored Accounts' RedmineID #64067
		- 20180911@Winnie: Add IsVip RedmineID #99982
		- 20190130@Winnie: Hardcode for this account BA03RM headline RedmineID #108504
	Parameter's Explanation:				
		- @TypeAccount =1: Headline
						2: Direct account
						3: Both
	Example: EXEC Acc_CRM_InformHeadlineSel @Currency = '20,10,2', @Level = '3,4', @Site = '6004,6006,6014,6016,6019,6023,6024', @TypeAccount = 3
*/
BEGIN
	SET NOCOUNT ON
	IF @Currency = '' OR @Level = '' OR @Site = ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'At least 1 option is selected.'
		RETURN
	END	
	DECLARE @tmpCurrency TABLE (currency INT)	
	DECLARE @CustID INT=2512
	DECLARE @CurrencyID INT
	DECLARE @Site1 VARCHAR(10)
	DECLARE @RoleID INT

	SELECT @CurrencyID=Currency,@Site1=site,@RoleID=@RoleID FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid=@CustID

	INSERT INTO @tmpCurrency
	SELECT val
	FROM f_CRM_strSplit (@Currency,',')
	
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY, GroupID INT)	
	INSERT INTO #DirectAcc (CustID, GroupID)
	SELECT a.CustID, GroupID FROM bodb02.dbo.f_InformHeadlineList (@Currency, @Level, @Site, @TypeAccount) a
	LEFT JOIN crmCustomer b WITH (NOLOCK) ON a.CustID=b.CustID			
	WHERE (ISNULL(@Ignored,0)=0 OR ISNULL(ignored,0) <> @Ignored)
		AND (@IsVip IS NULL OR @IsVip=IsVIP)

	IF @Site=@Site1 AND @TypeAccount IN(1,3) AND EXISTS(SELECT 1 FROM @tmpCurrency WHERE currency=@CurrencyID) AND @Level=@RoleID
	BEGIN
		INSERT INTO #DirectAcc (CustID, GroupID)
		SELECT 2512,134
	END

	IF @ItemsPerPage = -1 -- Export excel purpose
		SELECT	ID, HeadlineID, username, GroupID,
				45006 AS InformHeadlineStatusID			
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY CASE WHEN hl.GroupID > 0 THEN 1 ELSE 0 END DESC, c.username) AS ID,
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
				SELECT	ROW_NUMBER() OVER ( ORDER BY CASE WHEN hl.GroupID > 0 THEN 1 ELSE 0 END DESC, c.username) AS ID,
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