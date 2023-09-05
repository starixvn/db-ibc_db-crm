/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicLogSel]
	@PicName		NVARCHAR(200) = '',
	@DisplayName	NVARCHAR(1000) = '',
	@EditBy			VARCHAR(30)  = '', 
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@PageSize		INT = 100,
	@PageIndex		INT = 1,
	@TotalRows		INT = 0 OUTPUT
	  
AS
/*
	Created: 20200724@Malcolm
	Task :  CRM - PIC and Headline -> Changes Log -> Pic tab
	DB: DBCRM/bodb_CRM
	Original:

		Revisions:
			- 20200724@Malcolm: Get log of PIC [Redmine: #137144]
			- 20210726@Malcolm: Get pic type [Redmine: #151509]
			- 20221028@Malcolm: Get conversation group [Redmine: #179240]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]

		Param's Explanation:
*/
BEGIN 
	SET NOCOUNT ON

	SELECT @PicName = ISNULL(@PicName, ''), @EditBy = ISNULL(@EditBy,''), @DisplayName = ISNULL(@DisplayName, '')
		,@FromDate = DATEADD(HOUR,-12, @FromDate), @ToDate = DATEADD(HOUR,-12, @ToDate)

	IF @PicName <> '' OR @DisplayName <> ''
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM dbo.crmPIC p WITH(NOLOCK) WHERE p.Username = @PicName OR @PicName = '')
		   OR NOT EXISTS (SELECT 1 FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationGroupName = @DisplayName OR @DisplayName = '')
		   OR (@PicName <> '' AND @DisplayName <> '')
		BEGIN
			SELECT @TotalRows = 0
			GOTO Result
		END
	END

	DECLARE @Tmp TABLE 
	(
		LogID			BIGINT
		,LogDate		DATETIME
		,EditBy			VARCHAR(30)
		,[Name]			NVARCHAR(1000)
		,[PicType]		INT
		,ActionId		INT
		,NewValues		XML
		,OldValues		XML
		,ActionTypeID	INT
		,RowNum			INT
	)
	DECLARE @ConversationGroupId INT = 0, @NumberOfGroup INT = 0
	
	SELECT @NumberOfGroup = COUNT(1) FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationGroupName = @DisplayName

	IF @NumberOfGroup = 1
	BEGIN
		SELECT @ConversationGroupId = ConversationGroupId
		FROM dbo.crmConversationGroup WITH(NOLOCK) 
		WHERE ConversationGroupName = @DisplayName
	END
	IF @NumberOfGroup <= 1 OR @DisplayName = ''
	BEGIN
		SELECT @TotalRows = COUNT(1)
		FROM dbo.crmUserLog_RunSP r WITH(NOLOCK)
			INNER JOIN dbo.crmLogAction l WITH(NOLOCK) ON l.ActionID = r.ActionID
			LEFT JOIN dbo.crmPIC p WITH(NOLOCK) ON r.CustID = p.PicID AND l.ActionTypeID = 1 
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON r.UserID = c.custid
		WHERE l.ActionTypeID IN (CASE WHEN @DisplayName <> '' THEN 0 ELSE 1 END, CASE WHEN @PicName <> '' THEN 0 ELSE 5 END) 
			AND r.LogDate >= @FromDate AND r.LogDate <= @ToDate AND (@EditBy = '' OR c.username = @EditBy)
			AND (@PicName = '' OR p.Username = @PicName)
			AND (@DisplayName = '' OR (CONVERT(XML, NewValues)).exist('(//ConversationGroup[1]/@Id[number()=sql:variable("@ConversationGroupId")])') = 1 AND @ConversationGroupId <> 0)

		INSERT INTO @Tmp (LogID, LogDate, EditBy, [Name], [PicType], ActionId, NewValues, OldValues, ActionTypeID)
		SELECT 
			r.LogID
			,DATEADD(HOUR,12,r.LogDate) AS LogDate
			,c.username AS EditBy
			,ISNULL(p.Username, '') AS [PicName]
			,p.[PicType] AS [PicType]
			,r.ActionID
			,r.NewValues
			,r.OldValues
			,l.ActionTypeID 
		FROM dbo.crmUserLog_RunSP r WITH(NOLOCK)
			INNER JOIN dbo.crmLogAction l WITH(NOLOCK) ON l.ActionID = r.ActionID
			LEFT JOIN dbo.crmPIC p WITH(NOLOCK) ON r.CustID = p.PicID AND l.ActionTypeID = 1 
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON r.UserID = c.custid
		WHERE l.ActionTypeID IN (CASE WHEN @DisplayName <> '' THEN 0 ELSE 1 END, CASE WHEN @PicName <> '' THEN 0 ELSE 5 END) 
			AND r.LogDate >= @FromDate AND r.LogDate <= @ToDate AND (@EditBy = '' OR c.username = @EditBy)
			AND (@PicName = '' OR p.Username = @PicName)
			AND (@DisplayName = '' OR (CONVERT(XML, NewValues)).exist('(//ConversationGroup[1]/@Id[number()=sql:variable("@ConversationGroupId")])') = 1 AND @ConversationGroupId <> 0)
		ORDER BY r.LogID DESC
		OFFSET (@PageIndex - 1) * @PageSize ROWS
		FETCH NEXT @PageSize ROWS ONLY
	END
	ELSE
	BEGIN
		DECLARE @Sql NVARCHAR(MAX) = '', @ExpressGroupIds NVARCHAR(MAX) = ''

		SELECT @ExpressGroupIds = '*[ConversationGroup/@Id = 1]'

		SELECT @ExpressGroupIds = STRING_AGG('ConversationGroup/@Id = ' + CONVERT(VARCHAR(MAX), g.ConversationGroupId), ' or ')
		FROM dbo.crmConversationGroup g WITH(NOLOCK)
		WHERE g.ConversationGroupName = @DisplayName

		SELECT @ExpressGroupIds = '*[' + @ExpressGroupIds + ']'
		
		SELECT @Sql = '
		SELECT 
			r.LogID
			,DATEADD(HOUR,12,r.LogDate) AS LogDate
			,c.username AS EditBy
			,NULL AS [PicName]
			,NULL AS [PicType]
			,r.ActionID
			,r.NewValues
			,r.OldValues
			,l.ActionTypeID 
		FROM dbo.crmUserLog_RunSP r WITH(NOLOCK)
			INNER JOIN dbo.crmLogAction l WITH(NOLOCK) ON l.ActionID = r.ActionID
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON r.UserID = c.custid
		WHERE l.ActionTypeID = 5 AND r.LogDate >= ''' + CONVERT(VARCHAR(20), @FromDate, 120) + ''' AND r.LogDate <= '''+ CONVERT(VARCHAR(20), @ToDate, 120) 
			+''' AND (''' + @EditBy + '''= '''' OR c.username = ''' + @EditBy + ''')'
			+' AND (CONVERT(XML, NewValues)).exist('''+ @ExpressGroupIds +''') = 1'

		INSERT INTO @Tmp (LogID, LogDate, EditBy, [Name], [PicType], ActionId, NewValues, OldValues, ActionTypeID)
		EXEC (@Sql)

		SELECT @TotalRows = COUNT(1) FROM @Tmp
	END
	
	Result:
	SELECT     
		t.LogID
		,t.LogDate 
		,t.EditBy
		,t.[Name] 
		,CASE WHEN t.ActionTypeID = 1 THEN s.SettingValue 
		 ELSE NULL END AS [PicTypeName]
		,a.ActionNameEN AS [Action]
		,t.ActionId
		,t.NewValues 
		,t.OldValues
	FROM @Tmp t
		INNER JOIN dbo.crmLogAction a WITH(NOLOCK) ON t.ActionID = a.ActionID
		LEFT JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.[PicType] AND t.ActionTypeID = 1
	ORDER BY t.LogID DESC

END