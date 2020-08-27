/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_DirectAccountLogSel]
	@UserName		VARCHAR(30) = '',
	@EditBy			VARCHAR(30)  = '', 
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@ActionTypeIds  VARCHAR(100),
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT  
AS
/*
Created: 20200724@Malcolm
Task :  Get log of user and headline 
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200724@Malcolm: Get log of user and headline [Redmine: #137144]
	Param's Explanation:

		
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @Tmp TABLE 
	(
		LogID			BIGINT,
		LogDate			DATETIME,
		EditBy			VARCHAR(30),
		DirectAccount	VARCHAR(30),
		Action			NVARCHAR(100),
		ActionId        INT,
		OldValues		NVARCHAR(MAX),
		NewValues		NVARCHAR(MAX),
		RowNum          INT
	)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1,@RowEnd = @RowStart + @PageSize - 1

	SELECT @UserName = ISNULL(@UserName, ''), @EditBy = ISNULL(@EditBy, '')

	SELECT @FromDate = DATEADD(HOUR,-12,@FromDate), @ToDate = DATEADD(HOUR,-12,@ToDate)

	INSERT INTO @Tmp
	(
		LogID,			
		LogDate,			
		EditBy,			
		DirectAccount,	
		Action,		
		ActionId,
		OldValues,		
		NewValues,
		RowNum
	)
	SELECT 
		r.LogID,
		DATEADD(HOUR,12,r.LogDate) AS LogDate,
		e.username AS EditBy,
		c.username AS DirectAccount,
		l.ActionNameEN AS Action,
		r.ActionID,
		r.OldValues,
		r.NewValues,
		ROW_NUMBER() OVER(ORDER BY r.LogDate DESC, r.LogId DESC) AS RowNum
	FROM dbo.crmUserLog_RunSP r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = r.CustID
		INNER JOIN bodb02.dbo.Customer e WITH(NOLOCK) ON e.custid = r.UserID
		INNER JOIN dbo.crmLogAction l WITH(NOLOCK) ON l.ActionID = r.ActionID
	WHERE  r.LogDate >= @FromDate AND r.LogDate <= @ToDate
		AND (c.username = @UserName OR @UserName = '')
		AND (e.username = @EditBy OR @EditBy = '')
		AND (l.ActionTypeID IN (SELECT Val FROM bodb02.dbo.strSplit(@ActionTypeIds, ','))) 

	SELECT @TotalRows = COUNT(*) FROM @Tmp

	IF @PageIndex >= 0 AND @PageSize > 0
	BEGIN
		DELETE t FROM @Tmp t WHERE t.RowNum < @RowStart OR t.RowNum > @RowEnd
	END
	
	SELECT  LogID,			
			LogDate,		
			EditBy,			
			DirectAccount,
			Action,
			ActionId,
			OldValues,		
			NewValues
	FROM @Tmp
	ORDER BY LogDate DESC, LogID DESC
	
END