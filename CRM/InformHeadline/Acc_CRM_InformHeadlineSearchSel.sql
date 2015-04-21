ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineSearchSel]
	@TitleID		INT,
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@ChangeFilter	BIT, 	
	@ErrCode		INT	= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT	
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Search inform headline
	DB: DBCRM/bodb_CRM
		
	Revisions:

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
	
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY, GroupID INT)	
	INSERT INTO #DirectAcc (CustID, GroupID)
	SELECT CustID, GroupID FROM bodb02.dbo.f_InformHeadlineList (@Currency, @Level, @Site, @TypeAccount) 	

	IF @ChangeFilter = 1 --if filter is changed
	BEGIN
		SELECT	--*
				ISNULL(ih.HeadlineID, ac.CustID) AS HeadlineID,
				ISNULL(ih.GroupID, ac.GroupID) AS GroupID,
				ISNULL(ihc.username, acc.username) AS Username,
				ISNULL(ih.InformHeadlineStatusID, 45006) AS InformHeadlineStatusID,
				ih.UpdatedTime, 
				ISNULL(ih.Remark, '') AS Remark,
				ISNULL(handler.Username, '') AS Handler,
				st.SettingValue AS Extension,
				ih.ProductStatus,				
				CASE WHEN ih.GroupID IS NULL THEN 2 WHEN ac.GroupID IS NULL AND ih.InformHeadlineStatusID <> 45007 THEN 1 ELSE 0 END AS Cases
		FROM crmInformHeadline ih WITH (NOLOCK)
			FULL OUTER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID AND ih.HeadlineID = ac.CustID
			LEFT JOIN bodb02.dbo.CustInfo ihc WITH (NOLOCK) ON ih.HeadlineID = ihc.CustID
			LEFT JOIN bodb02.dbo.custInfo acc WITH (NOLOCK) ON ac.CustID = acc.CustID
			LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.CustID
			LEFT JOIN crmSetting st WITH (NOLOCK) ON ih.Extension = st.SettingID AND st.SettingName = 'Station'	
		WHERE (ih.TitleID = @TitleID OR ih.TitleID IS NULL) AND (ih.IsInform = 1 OR ih.IsInform IS NULL)
		ORDER BY ih.GroupID DESC, Username
	END
	ELSE --if filter is not changed
	BEGIN
		CREATE TABLE #NewDirectAcc (CustID_New INT, GroupID_New INT, CustID_Old INT, GroupID_Old INT, Cases TINYINT)
		--Get headline list who is found or removed now
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.HeadlineID IS NULL THEN 2 ELSE CASE WHEN ci.closed=0 AND ISNULL(ci.reject,0)=0 AND ci.Enabled=1 THEN 5 ELSE 1 END END
		FROM crmInformHeadline ih WITH (NOLOCK)
			FULL OUTER JOIN #DirectAcc ac ON ih.HeadlineID = ac.CustID
			LEFT JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON ih.HeadlineID = ci.custid
		WHERE ih.HeadlineID IS NULL OR ac.CustID IS NULL AND (ih.TitleID = @TitleID OR ih.TitleID IS NULL)
			AND (ih.IsInform = 1 OR ih.IsInform IS NULL) AND ih.InformHeadlineStatusID <> 45007

		--Get headline list who is changed group headline
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.GroupID = 0 THEN 4 ELSE 2 END
		FROM crmInformHeadline ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.HeadlineID = ac.CustID
		WHERE (ih.GroupID = 0 OR ac.GroupID = 0) AND ac.GroupID <> ih.GroupID AND ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007

		--Get headline list who is changed headlineID
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				3
		FROM crmInformHeadline ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID
		WHERE ih.GroupID <> 0 AND ih.HeadlineID <> ac.CustID AND ih.TitleID = @TitleID AND ih.IsInform = 1  AND ih.InformHeadlineStatusID <> 45007

		--Get headline list who is not changed
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				0
		FROM crmInformHeadline ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID AND ih.HeadlineID = ac.CustID
		WHERE ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007

		--Get headline list who is keep for reference
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ih.HeadlineID, ih.GroupID, ih.HeadlineID, ih.GroupID,
				0
		FROM crmInformHeadline ih WITH (NOLOCK)
		WHERE ih.TitleID = @TitleID AND ih.InformHeadlineStatusID = 45007

		SELECT	ac.CustID_Old, ciold.Username, ac.CustID_New, cinew.Username, 
				ac.GroupID_New AS GroupID,
				ih.InformHeadlineStatusID, 
				ih.UpdatedTime,
				ISNULL(ih.Remark,'') Remark,
				ISNULL(handler.username, '') AS Handler,
				st.SettingValue AS Extension,
				ih.ProductStatus,				
				ac.Cases
		FROM #NewDirectAcc ac
			LEFT JOIN crmInformHeadline ih WITH (NOLOCK) ON ac.CustID_Old = ih.HeadlineID AND ac.GroupID_Old = ih.GroupID
			LEFT JOIN bodb02.dbo.CustInfo cinew WITH (NOLOCK) ON ac.CustID_New = cinew.custid
			LEFT JOIN bodb02.dbo.CustInfo ciold WITH (NOLOCK) ON ac.CustID_Old = ciold.custid
			LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid
			LEFT JOIN crmSetting st WITH(NOLOCK) ON ih.Extension = st.SettingID AND st.SettingName = 'Station'	
		WHERE (ih.TitleID = @TitleID OR ih.TitleID IS NULL)
			AND (ih.IsInform = 1 OR ih.IsInform IS NULL)
		ORDER BY ac.Cases DESC, ac.GroupID_New DESC, cinew.Username

		DROP TABLE #NewDirectAcc
	END	

	DROP TABLE #DirectAcc 	
	
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSearchSel] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineSearchSel] TO [vnteam]