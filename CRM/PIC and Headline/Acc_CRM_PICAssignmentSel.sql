/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PICAssignmentSel]
	@Site			    VARCHAR(MAX) = '',
	@Currency			VARCHAR(1000) = '',
	@Status				VARCHAR(100) = '',
	@HeadlineType		INT = 2,
	@PicName			NVARCHAR(200) = '',	
	@DirectAccount		VARCHAR(50) = '',	
	@GroupHeadline		VARCHAR(50) = '',	
	@Position			VARCHAR(30) = '',
	@ExcludeIgnoredAcc	BIT = 0,
	@ExcludeAssignedAcc BIT = 0,
	@ExcludeIsTest		BIT = 0,	
	@PageSize			INT = 0,
	@PageIndex			INT = 0,
	@TotalRows			INT = 0 OUTPUT,
	@TotalUnassigned    INT = 0 OUTPUT
AS
/*
Created: 20200506@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: CRM - Staff/Boss Management of headline [Redmine: #108739]
	Param's Explanation:
		@HeadlineType = 0 : Normal
		              = 1 : VIP
					  = 2 : All
		
*/
BEGIN 
	SET NOCOUNT ON

	CREATE TABLE #Tmp_DirectAccount
	(

		CustID			INT PRIMARY KEY,
		Username		VARCHAR(30),
		Status			VARCHAR(10),
		Site			VARCHAR(20),
		Position		VARCHAR(20),
		Currency		INT,
		HeadlineID		INT,
		HeadlineName	VARCHAR(30),
		HeadlineType	INT,
		GroupID         INT,
		RowNum          INT
	)

	DECLARE @tblGroupHeadline TABLE (GroupId INT)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @ExcludeIsTest = ISNULL(@ExcludeIsTest,0),@ExcludeIgnoredAcc = ISNULL(@ExcludeIgnoredAcc,0),@PicName = ISNULL(@PicName,''),
		   @DirectAccount = ISNULL(@DirectAccount,''),@GroupHeadline = ISNULL(@GroupHeadline,''), @Position = ISNULL(@Position,''),
		   @Currency = ISNULL(@Currency,''),@Status = ISNULL(@Status,''),@Site = ISNULL(@Site,''),@HeadlineType = ISNULL(@HeadlineType,2)

	INSERT INTO #Tmp_DirectAccount(CustID, Username, Status, Site, Position, Currency, GroupID)
	SELECT cda.CustID,
		   c.Username,
		   CASE WHEN ISNULL(o.Enabled,0) = 0 THEN 'Disabled' 
				WHEN ISNULL(o.closed,0)  = 1 THEN 'Closed'
				WHEN ISNULL(o.reject,0)  = 1 THEN 'Suspended'
				ELSE 'Open' END AS [Status],
		   ISNULL(ag.site, c.site) AS [Site],
		   CASE c.roleid WHEN 1 THEN 'Member'
			             WHEN 2 THEN 'Agent'
						 WHEN 3 THEN 'Master'
						 WHEN 4 THEN 'Super'
		   ELSE NULL END AS Position,
		   c.currency,
		   ISNULL(ca.groupID, 0) AS GroupID
	FROM bodb02.dbo.CustDirectAccount cda WITH(NOLOCK)			
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON cda.custid = c.custid		
		INNER JOIN bodb02.dbo.custinfo o WITH(NOLOCK) ON o.custid = c.custid
		LEFT JOIN bodb02.dbo.Customer ag WITH(NOLOCK) ON ag.custid = c.recommend AND c.roleid = 1
		OUTER APPLY (SELECT TOP 1 ca.GroupId FROM bodb02.dbo.custAccount ca WITH(NOLOCK) WHERE cda.CustID = ca.custid) ca
		CROSS APPLY (SELECT TOP 1 s.custid FROM bodb02.dbo.CustSuper s WITH(NOLOCK) WHERE s.IsInternal = 0 AND s.custid = c.srecommend) s
	WHERE (@Site = '' OR ',' + @Site + ',' LIKE '%,' + ISNULL(ag.site, c.site)  + ',%')
		AND (@DirectAccount = '' OR c.username LIKE '%' + @DirectAccount + '%')
		AND (@ExcludeIsTest = 0 OR  c.currency NOT IN (20,27,28))
		AND (@Currency = '' OR ',' + @Currency + ',' LIKE '%,' + CONVERT(VARCHAR(4),c.currency) + ',%')
		AND (@Position = '' OR ',' + @Position + ',' LIKE '%,' + CONVERT(VARCHAR(3),c.roleid) + ',%')

	IF @Status <> ''
	BEGIN
		DELETE T
		FROM #Tmp_DirectAccount T
		WHERE ',' + @Status + ',' NOT LIKE '%,' + T.Status + ',%'
	END

	IF @ExcludeAssignedAcc = 1
	BEGIN
		DELETE t
		FROM #Tmp_DirectAccount t
		WHERE EXISTS(SELECT 1 FROM crmPicManagement m WITH(NOLOCK) WHERE m.CustID = t.CustID)
	END

	CREATE NONCLUSTERED INDEX ix_GroupID ON #Tmp_DirectAccount (GroupID)

	IF @ExcludeIgnoredAcc = 1
	BEGIN
		-- Group headline is ignored --> remove all member in this group
		DELETE T
		FROM #Tmp_DirectAccount t
		WHERE EXISTS (
			SELECT 1
			FROM bodb02.dbo.CustGroupHeadline h WITH(NOLOCK)
				INNER JOIN dbo.crmCustomer c WITH(NOLOCK) ON c.CustID = h.CustID
			WHERE t.GroupID = h.GroupID
				AND h.GroupID <> 0
				AND c.Ignored = 1
		)

		-- remove Customers ignored
		DELETE t
		FROM #Tmp_DirectAccount t
		WHERE EXISTS (
			SELECT 1
			FROM dbo.crmCustomer c WITH(NOLOCK)
			WHERE c.CustID = t.CustID
				AND c.Ignored = 1
		)
	END

	IF @HeadlineType <> 2
	BEGIN
		DELETE t
		FROM #Tmp_DirectAccount t
		WHERE NOT EXISTS(
			SELECT 1 
			FROM bodb02.dbo.CustGroupHeadline h WITH(NOLOCK)
				INNER JOIN dbo.crmCustomer c WITH(NOLOCK) ON h.CustID = c.CustID
			WHERE h.GroupID = t.GroupID AND ISNULL(c.IsVIP,0) = @HeadlineType AND t.GroupID <> 0
		)
	END

	IF @GroupHeadline <> ''
	BEGIN
		INSERT INTO @tblGroupHeadline (GroupId)
		SELECT cgh.GroupId
		FROM bodb02.dbo.CustGroupHeadline cgh WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON c.custid = cgh.CustID
		WHERE username LIKE '%' + @GroupHeadline + '%'

		DELETE t
		FROM #Tmp_DirectAccount t
		WHERE NOT EXISTS (SELECT 1 FROM @tblGroupHeadline gh WHERE t.GroupID = gh.GroupID)
	END

	IF @PicName <> ''
	BEGIN
		DELETE t
		FROM #Tmp_DirectAccount t
		WHERE NOT EXISTS(
			SELECT 1 
			FROM dbo.crmPIC p WITH(NOLOCK)
				INNER JOIN dbo.crmPicManagement m WITH(NOLOCK) ON m.PicID = p.PicID
			WHERE m.CustID = t.CustID AND p.Username  LIKE '%' + @PicName + '%' 
		)
	END
		
	UPDATE t
	SET t.HeadlineName = c.username,
		t.HeadlineID   = c.custid
	FROM #Tmp_DirectAccount t
		INNER JOIN bodb02.dbo.CustGroupHeadline h WITH(NOLOCK) ON t.GroupID = h.GroupID
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = h.CustID

	SELECT @TotalRows = COUNT(*) FROM #Tmp_DirectAccount

	SELECT @TotalUnassigned = COUNT(*) 
	FROM #Tmp_DirectAccount t
	WHERE NOT EXISTS(SELECT 1 FROM crmPicManagement m WITH(NOLOCK) WHERE m.CustID = t.CustID) 

	UPDATE x
	SET x.ROWNUM = x.NewRowNum
	FROM (
		SELECT RowNum, 
			   ROW_NUMBER() OVER(ORDER BY CASE WHEN t.HeadlineID IS NULL THEN 1 ELSE 0 END, t.HeadlineName, t.Username) AS NewRowNum
		FROM #Tmp_DirectAccount t
      ) x

    IF @PageSize > 0 AND @PageIndex>= 0
		DELETE t
		FROM #Tmp_DirectAccount t
		WHERE RowNum < @RowStart OR RowNum > @RowEnd

	SELECT  ISNULL(t.HeadlineID,0) AS HeadlineID,
			ISNULL(t.HeadlineName,'Not assigned group')	AS HeadlineName, 
		    CASE WHEN t.HeadlineID IS NULL   THEN NULL
			     WHEN  ISNULL(c.IsVIP,0) = 0 THEN 'Normal'
			ELSE 'VIP' END AS HeadlineType, 
			t.CustID AS DirectAccountID, 
			t.Username AS DirectAccount,
			t.Status, 
			t.Site,
			ex.currency,		
			t.Position,
	        l.PIC AS PIC

	FROM #Tmp_DirectAccount t 
		LEFT JOIN dbo.crmCustomer c WITH (NOLOCK) ON t.HeadlineID = c.CustID
		LEFT JOIN bodb02.dbo.Exchange ex WITH (NOLOCK) ON t.Currency = ex.exchangeid 
	OUTER APPLY(
		  SELECT  (		
					CONVERT(XML,(SELECT p.Username AS '@PicName', ISNULL(r.SettingValue,'') AS '@Role', p.PicID AS '@PicID', ISNULL(r.DisplayOrder,0) AS '@Order', p.Role AS '@RoleId'
					FROM dbo.crmPicManagement c WITH(NOLOCK) 
						INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON c.PicID = p.PicID
						LEFT JOIN dbo.crmSetting r WITH(NOLOCK) ON r.SettingID = p.Role 
					WHERE c.CustID = t.CustID 
					FOR XML PATH('PIC'),ROOT('ROOT')))
				  )
	)l(PIC)

	DROP TABLE #Tmp_DirectAccount
END