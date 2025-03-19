/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_HeadlineSel]
	@Username VARCHAR(30) = ''
	,@Limit INT = NULL
	,@ExcludeNotAssignedGroup BIT = 0
AS
/*
Created: 20200511@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200511@Malcolm: Get all headline of system [Redmine: #108739]
		- 20200813@Malcolm: Get top @Limit headline [Redmine : #130544]
		- 20241225@Tacy: CRM - Offer Direct Member for Super and Master [Redmine: #215809]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON

	SELECT @Username = ISNULL(@Username,''), @ExcludeNotAssignedGroup = ISNULL(@ExcludeNotAssignedGroup, 0)

	DECLARE @Tmp TABLE 
	(
		HeadlineId		INT
		,HeadlineName	VARCHAR(30)
		,RowNum         INT IDENTITY(1,1)
	)
	INSERT INTO @Tmp
	(
		HeadlineId
		,HeadlineName
	)
	SELECT c.custid AS HeadlineID,
		   t.username AS HeadlineName
	FROM bodb02.dbo.CustGroupHeadline c WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer t WITH(NOLOCK) ON c.custid = t.custid
	WHERE (@Username = '' OR t.username LIKE '%'+ @Username + '%') AND c.GroupID <> 0 AND t.site <> 'CN88'
	ORDER BY t.username
		
	-- for direct account which haven't headline group
	INSERT INTO @Tmp (HeadlineId, HeadlineName)
	SELECT 0 AS HeadlineID,'Not Assigned Group' AS HeadlineName
	WHERE @ExcludeNotAssignedGroup = 0 
		AND (@Username = '' OR 'Not Assigned Group' LIKE '%' + @Username + '%')

	SELECT 
		HeadlineId
		,HeadlineName
	FROM @Tmp
	WHERE (RowNum <= @Limit OR @Limit IS NULL)
END
GO