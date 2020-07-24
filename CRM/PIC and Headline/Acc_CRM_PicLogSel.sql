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
Task :  Get log of PIC
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200724@Malcolm: Get log of PIC [Redmine: #137144]
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
		ActionId	INT, 
		NewValues	XML,
		OldValues	XML,
		RowNum		INT
	)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PicName = ISNULL(@PicName, ''), @EditBy = ISNULL(@EditBy,'')

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1,@RowEnd = @RowStart + @PageSize - 1

	INSERT INTO @Tmp
	(
		LogID,
		LogDate, 
		EditBy,
		PIC, 
		ActionId,
		NewValues,
		OldValues,
		RowNum
	)
	SELECT 
		r.LogID, 
		r.LogDate, 
		c.username AS Edit_By, 
		p.Username AS PIC, 
		r.ActionID,
		r.NewValues,
		r.OldValues,
	    ROW_NUMBER() OVER(ORDER BY r.LogDate) AS RowNum
	FROM dbo.crmUserLog_RunSP r WITH(NOLOCK)
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON r.CustID = p.PicID 
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON r.UserID = c.custid
	WHERE r.ActionID IN (901, 902, 903) AND r.LogDate >= @FromDate AND r.LogDate <= @ToDate 
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
		a.ActionNameEN AS [Action], 
		t.ActionId,
		t.NewValues, 
		t.OldValues
	FROM @Tmp t
		INNER JOIN dbo.crmLogAction a WITH(NOLOCK) ON t.ActionID = a.ActionID

END