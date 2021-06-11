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
		- 20200814@Malcolm: Get default Pics [Redmine: #137144]
		- 20200921@Percy: Enhance code to improve performance [RedmineId: #130544]
		- 20210316@Malcolm: Get information of PIC [Redmine: #148881]
		- 20210611@Malcolm: Enhance the Lock Access & indirect close account status[RedmineId: #152350]

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
		RoleId          TINYINT,
		Status			VARCHAR(10),
		Site			VARCHAR(20),
		Position		VARCHAR(20),
		Currency		INT,
		HeadlineID		INT,
		HeadlineName	VARCHAR(30),
		HeadlineType	INT,
		GroupID         INT,
		Recommend       INT,
		RowNum          INT
	)

	CREATE TABLE #PicTable (PicId INT)

	DECLARE @tblGroupHeadline TABLE (GroupId INT)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @ExcludeIsTest = ISNULL(@ExcludeIsTest,0),@ExcludeIgnoredAcc = ISNULL(@ExcludeIgnoredAcc,0),@PicName = ISNULL(@PicName,''),
		   @DirectAccount = ISNULL(@DirectAccount,''),@GroupHeadline = ISNULL(@GroupHeadline,''), @Position = ISNULL(@Position,''),
		   @Currency = ISNULL(@Currency,''),@Status = ISNULL(@Status,''),@Site = ISNULL(@Site,''),@HeadlineType = ISNULL(@HeadlineType,2)

	INSERT INTO #Tmp_DirectAccount(CustID, Username, Status, Site, Position, Currency, GroupID, Recommend, RoleId)
	SELECT cda.CustID,
		   c.Username,
		   CASE WHEN ISNULL(o.Enabled,0) = 0 THEN 'Disabled' 
				WHEN ISNULL(cps.CloseInfo,0) > 0 THEN 'Closed'
				WHEN ISNULL(cps.SuspendInfo,0)  > 0 THEN 'Suspended'
				WHEN ISNULL(cps.Locked, 0) > 0 THEN 'Locked'
				ELSE 'Open' END AS [Status],
		   c.site AS [Site],
		   CASE c.roleid WHEN 1 THEN 'Member'
			             WHEN 2 THEN 'Agent'
						 WHEN 3 THEN 'Master'
						 WHEN 4 THEN 'Super'
		   ELSE NULL END AS Position,
		   c.currency,
		   ISNULL(ca.groupID, 0) AS GroupID,
		   recommend = c.recommend,
		   roleid = c.roleid
	FROM bodb02.dbo.CustDirectAccount cda WITH(NOLOCK)			
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON cda.custid = c.custid		
		INNER JOIN bodb02.dbo.custinfo o WITH(NOLOCK) ON o.custid = c.custid
		INNER JOIN bodb02.dbo.CustProductStatus cps WITH(NOLOCK) ON cps.CustID = c.custid
		OUTER APPLY (SELECT TOP 1 ca.GroupId FROM bodb02.dbo.custAccount ca WITH(NOLOCK) WHERE cda.CustID = ca.custid) ca
	WHERE (@Site = '' OR ',' + @Site + ',' LIKE '%,' + c.site  + ',%')
		AND (@DirectAccount = '' OR c.username LIKE '%' + @DirectAccount + '%')
		AND (@ExcludeIsTest = 0 OR  c.currency NOT IN (20,27,28))
		AND (@Currency = '' OR ',' + @Currency + ',' LIKE '%,' + CONVERT(VARCHAR(4),c.currency) + ',%')
		AND (@Position = '' OR ',' + @Position + ',' LIKE '%,' + CONVERT(VARCHAR(3),c.roleid) + ',%')
    
	IF @Position = '' OR ',' + @Position + ',' LIKE '%,4,%' 
		DELETE T
		FROM #Tmp_DirectAccount T
		WHERE EXISTS(SELECT 1 FROM bodb02.dbo.CustSuper s WITH(NOLOCK) WHERE s.custid = T.CustID AND s.IsInternal = 1)
			AND T.RoleId = 4

	IF @Position = '' OR ',' + @Position + ',' LIKE '%,3,%' 
		DELETE T
		FROM #Tmp_DirectAccount T
		WHERE EXISTS(SELECT 1 FROM bodb02.dbo.CustMaster m WITH(NOLOCK) WHERE m.custid = T.CustID AND m.IsInternal = 1)
			AND T.RoleId = 3

	IF @Position = '' OR ',' + @Position + ',' LIKE '%,2,%'  OR ',' + @Position + ',' LIKE '%,1,%'
		DELETE T
		FROM #Tmp_DirectAccount T
		WHERE EXISTS(SELECT 1 FROM bodb02.dbo.CustAgent ag WITH(NOLOCK) WHERE ag.custid = T.Recommend AND ag.IsInternal = 1)
			AND T.RoleId IN (1, 2)

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
				LEFT JOIN dbo.crmCustomer c WITH(NOLOCK) ON h.CustID = c.CustID
			WHERE h.GroupID = t.GroupID AND ISNULL(c.IsVIP,0) = @HeadlineType AND t.GroupID <> 0
		)
	END

	IF @GroupHeadline <> ''
	BEGIN
		INSERT INTO @tblGroupHeadline (GroupId)
		SELECT cgh.GroupId
		FROM bodb02.dbo.CustGroupHeadline cgh WITH (NOLOCK)
			CROSS APPLY (
				SELECT TOP 1 c.CustId FROM bodb02.dbo.Customer c WITH (NOLOCK)
				WHERE c.custid = cgh.CustID
					AND c.username LIKE '%' + @GroupHeadline + '%'
			) c

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
		INNER JOIN bodb02.dbo.CustGroupHeadline h WITH(NOLOCK) ON t.GroupID = h.GroupID AND h.GroupID > 0
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = h.CustID

	DELETE t
	FROM #Tmp_DirectAccount t
	WHERE GroupID > 0 AND t.HeadlineID IS NULL

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
	        l.PIC AS PIC,
			d.PIC AS DefaultPIC

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
	OUTER APPLY(
		  SELECT  (		
					CONVERT(XML,(SELECT p.Username AS '@PicName', ISNULL(r.SettingValue,'') AS '@Role', p.PicID AS '@PicID',p.Role AS '@RoleId'
					FROM dbo.crmPICDefault c WITH(NOLOCK) 
						INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON c.PicID = p.PicID
						LEFT JOIN dbo.crmSetting r WITH(NOLOCK) ON r.SettingID = p.Role 
					WHERE c.HeadlineID = t.HeadlineID 
					FOR XML PATH('PIC'),ROOT('ROOT')))
				  )
	)d(PIC)

	INSERT INTO #PicTable (PicId)
	SELECT DISTINCT m.PicID
	FROM #Tmp_DirectAccount t
		INNER JOIN dbo.crmPicManagement m WITH(NOLOCK) ON t.CustID = m.CustID

	SELECT t.PicId, p.Username, e.SettingValue AS CommunicationTool, c.CommunicationValue, r.SettingID AS RoleId, ISNULL(r.DisplayOrder, 0) AS  [Order]
	FROM #PicTable t
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = t.PicId
		INNER JOIN dbo.crmPICCommunication c WITH(NOLOCK) ON c.PicID = t.PicId
		INNER JOIN dbo.crmSetting e WITH(NOLOCK) ON e.SettingID = c.CommunicationID AND e.IsActive = 1
		LEFT JOIN dbo.crmSetting r WITH(NOLOCK) ON r.SettingID = p.Role

	DROP TABLE #Tmp_DirectAccount, #PicTable
END