/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineSearchSel]
	@TitleID		INT,
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@Ignored		BIT=0,	
	@IsVip			TINYINT=2,
	@ErrCode		INT	= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT	
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Search inform headline
	DB: DBCRM/bodb_CRM
		
	Revisions:
		- 20150706@Elodie: Exclude NULL value to compare data (Redmine: #38953)
		- 20160915@Winnie: Return  'Checker' and 'Ignored Accounts' RedmineID #64067
		- 20190729@Winnie:Change function edit inform headline RedmineID: #109775
	Parameter's Explanation:				
		- @TypeAccount =1: Headline
						2: Direct account
						3: Both
		- @ChangeFilter =0: Not change
						=1: Change filter
	Example: EXEC Acc_CRM_InformHeadlineSearchSel @TitleID = 1, @Currency = '20,10,2', @Level = '3,4', @Site = 'BEST-ODDS,722222,222223', @TypeAccount = 3, @ChangeFilter = 0
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SiteHardcode VARCHAR(10)
	DECLARE @UsernameHardcode VARCHAR(30)
	DECLARE @tmpSite TABLE (Site VARCHAR(50))
	DECLARE @UplineID INT
	DECLARE @CustID INT=2512
	DECLARE @CurrencyID INT	
	DECLARE @TypeAccountHardcode INT
	DECLARE @tmpCurrency TABLE (currency INT)	
	DECLARE @RoleID INT
	DECLARE @tmpLevel TABLE (roleID TINYINT)	
	DECLARE @IgnoredHardCode BIT
	DECLARE @IsVipHardCode BIT

	INSERT INTO @tmpSite
	SELECT s.SiteName
	FROM f_split (@Site,',') v
		INNER JOIN dbo.crmSite s ON v.val = s.SiteID

	INSERT INTO @tmpCurrency
	SELECT val
	FROM f_split (@Currency,',')

	
	INSERT INTO @tmpLevel
	SELECT val
	FROM f_split (@Level,',')


	IF @Currency = '' OR @Level = '' OR @Site = ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'At least 1 option is selected.'
		RETURN
	END		
	SELECT @CurrencyID=Currency,@RoleID=RoleID,@UplineID=recommend FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid=@CustID
	
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

	SELECT	ac.CustID AS HeadlineID, ac.Username AS UserName,
					ISNULL(ih.GroupID,ac.GroupID) AS GroupID,
					ISNULL(ih.InformHeadlineStatusID,45006) AS InformHeadlineStatusID, 
					ih.UpdatedTime,
					ISNULL(ih.Remark,'') Remark,
					ISNULL(handler.username, '') AS Handler,
					ih.Extension,
					ih.ProductStatus			
			FROM #DirectAcc ac
				LEFT JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ac.CustID = ih.HeadlineID AND ih.TitleID = @TitleID			
				LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid	
			
	ORDER BY  CASE WHEN ih.GroupID > 0 THEN 1 ELSE 0 END DESC, UserName			

	DROP TABLE #DirectAcc 	
END



GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSearchSel] TO [bodbAdminNet]
