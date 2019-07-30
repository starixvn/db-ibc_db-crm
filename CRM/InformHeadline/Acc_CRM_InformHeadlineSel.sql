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
	@IsVip			TINYINT=2,
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
		- 20190311@Winnie: CRM - Enhance Inform Headline RedmineID:##109775
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
	DECLARE @UplineID INT
	DECLARE @CurrencyID INT
	DECLARE @SiteHardcode VARCHAR(10)
	DECLARE @UsernameHardcode VARCHAR(30)
	DECLARE @RoleID INT
	DECLARE @TypeAccountHardcode INT
	DECLARE @tmpSite TABLE (Site VARCHAR(50))	
	DECLARE @IgnoredHardCode BIT
	DECLARE @IsVipHardCode BIT
	DECLARE @tmpLevel TABLE (roleID TINYINT)	

	INSERT INTO @tmpLevel
	SELECT val
	FROM f_split (@Level,',')

	INSERT INTO @tmpSite
	SELECT s.SiteName
	FROM f_split (@Site,',') v
		INNER JOIN dbo.crmSite s ON v.val = s.SiteID

	SELECT @CurrencyID=Currency,@UplineID=recommend,@RoleID=RoleID FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid=@CustID

	SELECT @SiteHardcode=Site FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid=@UplineID

	SELECT @IgnoredHardCode=Ignored,@IsVipHardCode=ISNULL(IsVIP,0),@UsernameHardcode=UserName FROM crmCustomer WITH(NOLOCK) WHERE custid=@CustID

	IF EXISTS(SELECT 1 FROM bodb02.dbo.custAccount WITH(NOLOCK) WHERE custid=@CustID and IsGroupHeadLine=1)
	BEGIN
		SELECT @TypeAccountHardcode=1
	END
	ELSE IF  EXISTS(SELECT 1 FROM bodb02.dbo.Acc_CustDirect WITH(NOLOCK) WHERE custid=@CustID)
	BEGIN
		SELECT @TypeAccountHardcode=2
	END

	INSERT INTO @tmpCurrency
	SELECT val
	FROM f_split (@Currency,',')
	
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY, GroupID INT,Username VARCHAR(30))	
	INSERT INTO #DirectAcc (CustID, GroupID,Username)
	SELECT a.CustID, GroupID,a.Username FROM dbo.f_Inform_HeadlineList (@Currency, @Level, @Site, @TypeAccount) a
	LEFT JOIN crmCustomer b WITH (NOLOCK) ON a.CustID=b.CustID			
	WHERE (ISNULL(@Ignored,0)=0 OR ISNULL(ignored,0) <> @Ignored)
		AND ((@IsVip =2 AND IsVip IN(0,1)) OR @IsVip=IsVIP)

	IF EXISTS(SELECT 1 FROM @tmpSite WHERE Site=@SiteHardcode) 
		AND (@TypeAccount =@TypeAccountHardcode OR @TypeAccount=3) 
		AND EXISTS(SELECT 1 FROM @tmpCurrency WHERE currency=@CurrencyID) 
		AND EXISTS(SELECT 1 FROM @tmpLevel WHERE roleID=@RoleID) 
		AND (ISNULL(@Ignored,0)=0 OR ISNULL(@IgnoredHardCode,0) <> @Ignored)
		AND (@IsVip =2 OR @IsVip=@IsVipHardCode)
	BEGIN
		INSERT INTO #DirectAcc (CustID, GroupID,Username)
		SELECT @CustID,groupID,@UsernameHardcode
		FROM bodb02.dbo.custAccount WITH(NOLOCK)
		WHERE custid=@CustID
	END

	IF @ItemsPerPage = -1 -- Export excel purpose
		SELECT	ID, HeadlineID, username, GroupID,
				45006 AS InformHeadlineStatusID			
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY CASE WHEN hl.GroupID > 0 THEN 1 ELSE 0 END DESC, c.username) AS ID,
						hl.CustID AS HeadlineID, 
						hl.username,
						hl.GroupID
				FROM #DirectAcc hl				
				)tmp
	ELSE
		SELECT	ID, HeadlineID, username, GroupID,
				45006 AS InformHeadlineStatusID			
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY CASE WHEN hl.GroupID > 0 THEN 1 ELSE 0 END DESC, c.username) AS ID,
						hl.CustID AS HeadlineID, 
						hl.username,
						hl.GroupID
				FROM #DirectAcc hl					
				)tmp
		WHERE ID BETWEEN @PageIndex*@ItemsPerPage-@ItemsPerPage+1 AND @PageIndex*@ItemsPerPage

	DROP TABLE #DirectAcc 	
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSel] TO [bodbAdminNet]
GO