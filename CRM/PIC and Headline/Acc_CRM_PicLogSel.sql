/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicLogSel]
	@PicName		NVARCHAR(200) = '',
	@LetstalkName	NVARCHAR(1000) = '',
	@EditBy			VARCHAR(30)  = '', 
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
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
		Param's Explanation:
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @Tmp TABLE 
	(
		LogID		 BIGINT,
		LogDate		 DATETIME, 
		EditBy		 VARCHAR(30), 
		[Name]	     NVARCHAR(1000), 
		[Type]		 INT,
		ActionId	 INT, 
		NewValues	 XML,
		OldValues	 XML,
		ActionTypeID INT,
		RowNum		 INT
	)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PicName = ISNULL(@PicName, ''), @EditBy = ISNULL(@EditBy,''), @LetstalkName = ISNULL(@LetstalkName, '')

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1,@RowEnd = @RowStart + @PageSize - 1

	SELECT @FromDate = DATEADD(HOUR,-12,@FromDate), @ToDate = DATEADD(HOUR,-12,@ToDate)

	INSERT INTO @Tmp (LogID, LogDate, EditBy, [Name], [Type], ActionId, NewValues, OldValues, ActionTypeID)
	SELECT 
		r.LogID, 
		DATEADD(HOUR,12,r.LogDate) AS LogDate, 
		c.username AS EditBy, 
		ISNULL(p.Username, g.ConversationGroupName) AS [Name], 
		ISNULL(p.[PicType], g.ChatTypeId) AS [Type],
		r.ActionID,
		r.NewValues,
		r.OldValues,
	    l.ActionTypeID 
	FROM dbo.crmUserLog_RunSP r WITH(NOLOCK)
		INNER JOIN dbo.crmLogAction l WITH(NOLOCK) ON l.ActionID = r.ActionID
		LEFT JOIN dbo.crmPIC p WITH(NOLOCK) ON r.CustID = p.PicID AND l.ActionTypeID = 1 
		LEFT JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = r.CustID AND l.ActionTypeID = 5
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON r.UserID = c.custid
	WHERE l.ActionTypeID IN (1, 5) AND r.LogDate >= @FromDate AND r.LogDate <= @ToDate 
		AND (@PicName = '' OR p.Username = @PicName) 
		AND (@EditBy = '' OR c.username = @EditBy)
		AND (@LetstalkName = '' OR CHARINDEX(@LetstalkName, g.ConversationGroupName) >= 1)

	IF @PageIndex >= 0 AND @PageSize > 0
	BEGIN
		DELETE t FROM @Tmp t WHERE t.RowNum < @RowStart OR t.RowNum > @RowEnd
	END

	SELECT     
		t.LogID, 
		t.LogDate, 
		t.EditBy,
		t.[Name], 
		CASE WHEN t.ActionTypeID = 1 THEN s.SettingValue 
		     WHEN t.[Type] = 1 THEN 'Group'
			 WHEN t.[Type] = 2 THEN 'Personal'
		ELSE NULL END AS [TypeName],
		a.ActionNameEN AS [Action], 
		t.ActionId,
		t.NewValues, 
		t.OldValues
	FROM @Tmp t
		INNER JOIN dbo.crmLogAction a WITH(NOLOCK) ON t.ActionID = a.ActionID
		LEFT JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.[Type] AND t.ActionTypeID = 1
	ORDER BY t.LogDate DESC, t.LogID DESC

END