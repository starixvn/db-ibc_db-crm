/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineSearchSel]
	@TitleID		INT,
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@ChangeFilter	BIT, 
	@Ignored		BIT=0,	
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
		- 20190416@Winnie:Change function edit inform headline RedmineID: #109775

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
	SELECT a.CustID, GroupID FROM bodb02.dbo.f_InformHeadlineList (@Currency, @Level, @Site, @TypeAccount) a	
	LEFT JOIN crmCustomer b WITH (NOLOCK) ON a.CustID=b.CustID			
	WHERE (ISNULL(@Ignored,0)=0 OR ISNULL(ignored,0) <> @Ignored)
	
	/*CREATE TABLE #NewDirectAcc (CustID_New INT, GroupID_New INT, CustID_Old INT, GroupID_Old INT, Cases TINYINT)		

	--IF @ChangeFilter = 1 --if filter is changed
	--BEGIN
	--	INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
	--	SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,							
	--			CASE WHEN ih.GroupID IS NULL THEN 2 WHEN ac.GroupID IS NULL THEN 1 WHEN ih.GroupID = 0 AND ac.GroupID <> 0 THEN 4 WHEN ih.GroupID <> 0 AND ac.GroupID = 0 THEN 2 ELSE 0 END AS Cases
	--	FROM #DirectAcc ac
	--		FULL OUTER JOIN (SELECT * FROM crmInformHeadline_New WITH (NOLOCK) WHERE TitleID = @TitleID AND IsInform = 1 AND InformHeadlineStatusID <> 45007) ih ON ih.HeadlineID = ac.CustID		

	--	INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
	--	SELECT	ih.HeadlineID, ih.GroupID, ih.HeadlineID, ih.GroupID,							
	--			0 AS Cases
	--	FROM crmInformHeadline_New ih WITH (NOLOCK) 
	--	WHERE TitleID = @TitleID AND IsInform = 1 AND InformHeadlineStatusID = 45007
	--		AND ih.HeadlineID NOT IN (SELECT CustID_New FROM #NewDirectAcc WHERE CustID_New IS NOT NULL)		

	--	SELECT	ISNULL(ac.CustID_Old, ac.CustID_New) AS HeadlineID,
	--			ISNULL(ac.GroupID_Old, ac.GroupID_New) AS GroupID,
	--			ISNULL(ciold.username, cinew.username) AS Username,
	--			ISNULL(ih.InformHeadlineStatusID, 45006) AS InformHeadlineStatusID,
	--			ih.UpdatedTime, 
	--			ISNULL(ih.Remark, '') AS Remark,
	--			ISNULL(handler.Username, '') AS Handler,
	--			ih.Extension,
	--			ih.ProductStatus,				
	--			ac.Cases
	--	FROM #NewDirectAcc ac
	--		LEFT JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ac.CustID_Old = ih.HeadlineID AND ac.GroupID_Old = ih.GroupID AND ih.TitleID = @TitleID AND ih.IsInform = 1
	--		LEFT JOIN bodb02.dbo.CustInfo cinew WITH (NOLOCK) ON ac.CustID_New = cinew.custid
	--		LEFT JOIN bodb02.dbo.CustInfo ciold WITH (NOLOCK) ON ac.CustID_Old = ciold.custid
	--		LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.CustID
	--	ORDER BY Cases DESC, CASE WHEN ih.GroupID > 0 THEN 1 ELSE 0 END DESC, Username	
	--END
	--ELSE --if filter is not changed
	--BEGIN				
		
		--Step 1: Get headline list who is changed headlineID first
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				3
		FROM crmInformHeadline_New ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID
		WHERE ih.GroupID <> 0 AND ih.HeadlineID <> ac.CustID AND ih.TitleID = @TitleID AND ih.IsInform = 1  AND ih.InformHeadlineStatusID <> 45007

		--Step 2: Get headline list who is changed group headline
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.GroupID = 0 THEN 4 ELSE 2 END
		FROM crmInformHeadline_New ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.HeadlineID = ac.CustID
		WHERE (ih.GroupID = 0 OR ac.GroupID = 0) AND ac.GroupID <> ih.GroupID AND ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007
			AND ac.CustID NOT IN (SELECT CustID_New FROM #NewDirectAcc WHERE CustID_New IS NOT NULL)

		--Step 3: Get headline list who is not changed
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				0
		FROM crmInformHeadline_New ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID AND ih.HeadlineID = ac.CustID
		WHERE ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007

		--Get headline list who is found or removed now
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.HeadlineID IS NULL THEN 2 
				ELSE 
				CASE WHEN ci.closed=0 AND ISNULL(ci.reject,0)=0 AND ci.Enabled=1  THEN CASE WHEN ih.GroupID = 0 AND @ChangeFilter = 0 THEN 5 ELSE 1 END 
				ELSE 1 END END
		FROM #DirectAcc ac
			FULL OUTER JOIN (SELECT * FROM crmInformHeadline_New WITH (NOLOCK) WHERE TitleID = @TitleID AND IsInform = 1 AND InformHeadlineStatusID <> 45007) ih ON ih.HeadlineID = ac.CustID		
			LEFT JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON ih.HeadlineID = ci.custid
		WHERE (ih.HeadlineID IS NULL AND ac.CustID NOT IN (SELECT CustID_New FROM #NewDirectAcc WHERE CustID_New IS NOT NULL)) OR (ac.CustID IS NULL AND ih.HeadlineID NOT IN (SELECT CustID_Old FROM #NewDirectAcc WHERE CustID_Old IS NOT NULL))

		--Get headline list who is keep for reference
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ih.HeadlineID, ih.GroupID, ih.HeadlineID, ih.GroupID,
				0
		FROM crmInformHeadline_New ih WITH (NOLOCK)
		WHERE ih.TitleID = @TitleID AND ih.InformHeadlineStatusID = 45007 AND ih.IsInform = 1
			AND ih.HeadlineID NOT IN (SELECT CustID_New FROM #NewDirectAcc WHERE CustID_New IS NOT NULL)				

		SELECT * 
		FROM 
		(
			SELECT	ac.CustID_Old, ciold.Username AS UserName_Old, ac.CustID_New, cinew.Username AS UserName_New, 
					ac.GroupID_New AS GroupID,
					ih.InformHeadlineStatusID, 
					ih.UpdatedTime,
					ISNULL(ih.Remark,'') Remark,
					ISNULL(handler.username, '') AS Handler,
					ih.Extension,
					ih.ProductStatus,				
					ac.Cases
			FROM #NewDirectAcc ac
				LEFT JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ac.CustID_Old = ih.HeadlineID AND ac.GroupID_Old = ih.GroupID AND ih.TitleID = @TitleID AND ih.IsInform = 1
				LEFT JOIN bodb02.dbo.CustInfo cinew WITH (NOLOCK) ON ac.CustID_New = cinew.custid
				LEFT JOIN bodb02.dbo.CustInfo ciold WITH (NOLOCK) ON ac.CustID_Old = ciold.custid
				LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid		
			WHERE ac.Cases <> 2
			UNION ALL -- Group headline is removed from group and become dirrect account
			SELECT	ac.CustID_Old, ciold.Username AS UserName_Old, ac.CustID_New, cinew.Username AS UserName_New, 
					ac.GroupID_New AS GroupID,
					45006, 
					NULL,
					'' AS Remark,
					NULL AS Handler,
					0 AS Extension,
					0 AS ProductStatus,				
					ac.Cases
			FROM #NewDirectAcc ac
				INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ac.CustID_Old = ih.HeadlineID AND ac.GroupID_Old = ih.GroupID AND ih.TitleID = @TitleID AND ih.IsInform = 1
				LEFT JOIN bodb02.dbo.CustInfo cinew WITH (NOLOCK) ON ac.CustID_New = cinew.custid
				LEFT JOIN bodb02.dbo.CustInfo ciold WITH (NOLOCK) ON ac.CustID_Old = ciold.custid
			WHERE ac.Cases = 2
			UNION ALL -- Direct account is found again with  old custid and old groupID
			SELECT	ac.CustID_Old, ciold.Username AS UserName_Old, ac.CustID_New, cinew.Username AS UserName_New, 
					ac.GroupID_New AS GroupID,
					45006, 
					NULL,
					ISNULL(ih.Remark,'') Remark,
					ISNULL(handler.username, '') AS Handler,
					ih.Extension,
					ih.ProductStatus,			
					ac.Cases
			FROM #NewDirectAcc ac
				INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ac.CustID_New = ih.HeadlineID AND ac.GroupID_New = ih.GroupID AND ih.TitleID = @TitleID AND (ih.IsInform = 0 OR ih.InformHeadlineStatusID = 45007)
				LEFT JOIN bodb02.dbo.CustInfo cinew WITH (NOLOCK) ON ac.CustID_New = cinew.custid
				LEFT JOIN bodb02.dbo.CustInfo ciold WITH (NOLOCK) ON ac.CustID_Old = ciold.custid
				LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid		
			WHERE ac.Cases = 2
			UNION ALL -- Direct account is found again with  new groupID
			SELECT	ac.CustID_Old, ciold.Username AS UserName_Old, ac.CustID_New, cinew.Username AS UserName_New, 
					ac.GroupID_New AS GroupID,
					45006, 
					NULL,
					ISNULL(ih.Remark,'') Remark,
					ISNULL(handler.username, '') AS Handler,
					ih.Extension,
					ih.ProductStatus,			
					ac.Cases
			FROM #NewDirectAcc ac
				INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ac.CustID_New = ih.HeadlineID AND ac.GroupID_New <> ih.GroupID AND ih.TitleID = @TitleID AND (ih.IsInform = 0 OR ih.InformHeadlineStatusID = 45007)
				LEFT JOIN bodb02.dbo.CustInfo cinew WITH (NOLOCK) ON ac.CustID_New = cinew.custid
				LEFT JOIN bodb02.dbo.CustInfo ciold WITH (NOLOCK) ON ac.CustID_Old = ciold.custid
				LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid		
			WHERE ac.Cases = 2
			UNION ALL --Direct account is new found
			SELECT	ac.CustID_Old, ciold.Username AS UserName_Old, ac.CustID_New, cinew.Username AS UserName_New, 
					ac.GroupID_New AS GroupID,
					45006, 
					NULL,
					'' AS Remark,
					NULL AS Handler,
					0 AS Extension,
					0 AS ProductStatus,				
					ac.Cases
			FROM #NewDirectAcc ac
				LEFT JOIN bodb02.dbo.CustInfo cinew WITH (NOLOCK) ON ac.CustID_New = cinew.custid
				LEFT JOIN bodb02.dbo.CustInfo ciold WITH (NOLOCK) ON ac.CustID_Old = ciold.custid
			WHERE ac.Cases = 2 AND ac.CustID_New NOT IN (SELECT HeadlineID FROM crmInformHeadline_New WITH (NOLOCK) WHERE TitleID = @TitleID)
		) tmp
		ORDER BY Cases DESC, CASE WHEN GroupID > 0 THEN 1 ELSE 0 END DESC, UserName_New		

	DROP TABLE #NewDirectAcc
	*/
	SELECT	ac.CustID, cinew.Username AS UserName,
					ISNULL(ih.GroupID,ac.GroupID) AS GroupID,
					ih.InformHeadlineStatusID, 
					ih.UpdatedTime,
					ISNULL(ih.Remark,'') Remark,
					ISNULL(handler.username, '') AS Handler,
					ih.Extension,
					ih.ProductStatus			
			FROM #DirectAcc ac
				INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ac.CustID = ih.HeadlineID
				LEFT JOIN bodb02.dbo.CustInfo cinew WITH (NOLOCK) ON ac.CustID = cinew.custid				
				LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid	
	ORDER BY  CASE WHEN ih.GroupID > 0 THEN 1 ELSE 0 END DESC, UserName			

	DROP TABLE #DirectAcc 	
	
END


GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSearchSel] TO [bodbAdminNet]
