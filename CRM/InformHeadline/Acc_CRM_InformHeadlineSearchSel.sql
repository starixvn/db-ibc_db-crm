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
	IF @Currency = '' OR @Level = '' OR @Site = ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'At least 1 option is selected.'
		RETURN
	END		
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY, GroupID INT,Username VARCHAR(30))	
	INSERT INTO #DirectAcc (CustID, GroupID,Username)
	SELECT a.CustID, GroupID,Username FROM dbo.f_Inform_HeadlineList (@Currency, @Level, @Site, @TypeAccount) a	
		LEFT JOIN crmCustomer b WITH (NOLOCK) ON a.CustID=b.CustID			
	WHERE (ISNULL(@Ignored,0)=0 OR ISNULL(ignored,0) <> @Ignored)
		AND ((@IsVip =2 AND IsVip IN(0,1)) OR @IsVip=IsVIP)

	SELECT	ac.CustID, ac.Username AS UserName,
					ISNULL(ih.GroupID,ac.GroupID) AS GroupID,
					ih.InformHeadlineStatusID, 
					ih.UpdatedTime,
					ISNULL(ih.Remark,'') Remark,
					ISNULL(handler.username, '') AS Handler,
					ih.Extension,
					ih.ProductStatus			
			FROM #DirectAcc ac
				INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ac.CustID = ih.HeadlineID				
				LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid	
			WHERE ih.TitleID = @TitleID
	ORDER BY  CASE WHEN ih.GroupID > 0 THEN 1 ELSE 0 END DESC, UserName			

	DROP TABLE #DirectAcc 	
END


GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSearchSel] TO [bodbAdminNet]
