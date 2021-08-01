/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicLogSel]
	@PicName		NVARCHAR(200) = '',
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
	Param's Explanation:

		
*/
BEGIN 
	SET NOCOUNT ON

	

	DECLARE @Tmp TABLE 
	(
		LogID		BIGINT,
		LogDate		DATETIME, 
		EditBy		VARCHAR(30), 
		PIC			NVARCHAR(200), 
		Role		INT,
		[Type]		INT,
		ActionId	INT, 
		NewValues	XML,
		OldValues	XML,
		RowNum		INT
	)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PicName = ISNULL(@PicName, ''), @EditBy = ISNULL(@EditBy,'')

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1,@RowEnd = @RowStart + @PageSize - 1

	SELECT @FromDate = DATEADD(HOUR,-12,@FromDate), @ToDate = DATEADD(HOUR,-12,@ToDate)

	INSERT INTO @Tmp
	(
		LogID,
		LogDate, 
		EditBy,
		PIC, 
		Role,
		[Type],
		ActionId,
		NewValues,
		OldValues,
		RowNum
	)
	SELECT 
		r.LogID, 
		DATEADD(HOUR,12,r.LogDate) AS LogDate, 
		c.username AS Edit_By, 
		p.Username AS PIC, 
		p.[Role],
		p.[Type],
		r.ActionID,
		r.NewValues,
		r.OldValues,
	    ROW_NUMBER() OVER(ORDER BY r.LogDate DESC, r.LogId DESC) AS RowNum
	FROM dbo.crmUserLog_RunSP r WITH(NOLOCK)
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON r.CustID = p.PicID 
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON r.UserID = c.custid
		INNER JOIN dbo.crmLogAction l WITH(NOLOCK) ON l.ActionID = r.ActionID
	WHERE l.ActionTypeID = 1 AND r.LogDate >= @FromDate AND r.LogDate <= @ToDate 
		AND (@PicName = '' OR p.Username = @PicName) 
		AND (@EditBy = '' OR c.username = @EditBy)

	SELECT @TotalRows= COUNT(*) FROM @Tmp

	IF @PageIndex >= 0 AND @PageSize > 0
	BEGIN
		DELETE t FROM @Tmp t WHERE t.RowNum < @RowStart OR t.RowNum > @RowEnd
	END

	SELECT     
		t.LogID, 
		t.LogDate, 
		t.EditBy,
		t.PIC, 
		s.SettingValue AS [PicType],
		a.ActionNameEN AS [Action], 
		t.ActionId,
		t.NewValues, 
		t.OldValues
	FROM @Tmp t
		INNER JOIN dbo.crmLogAction a WITH(NOLOCK) ON t.ActionID = a.ActionID
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.[Type]
	ORDER BY t.LogDate DESC, t.LogID DESC

END