/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_LAP_AdmSelNoti
	@FEventDate DATE
	,@TEventDate DATE
	,@LanguageCode VARCHAR(10) = 'en'
	,@PageSize INT = 100
	,@PageIndex INT = 1
AS
/*
	Created: 20231213@Roy
	Task: Get all LAP Notifications by filter criteria
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
		@FEventDate, @TEventDate: Match.EventDate
		@LanguageCode:
						zh-CN: Simplified Chinese
						en: English
		@PageSize ,@PageIndex: handle paging
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AdmSelNoti
			@FNotiID = 1
			,@NotiType = 1
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @TotalRows INT = 0
	
	CREATE TABLE #tmpResult (
		RNo INT IDENTITY(1, 1) PRIMARY KEY
		,LAPNotiID INT
		,EventDate4GMT DATE
		,Subject NVARCHAR(1000)
		,Content_en NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	
	/*****************************************   APPLY filter criterias   *********************************************************/
	
	--Get LAP Notifications
	INSERT INTO #tmpResult (
		LAPNotiID
		,EventDate4GMT
		,Subject
		,Content_en
		,Content_cs
	)
	SELECT DISTINCT n.NotificationID
		,ne.EventDate
		,n.Subject
		,n.Content_en
		,n.Content_cs
	FROM dbo.Notification AS n WITH (NOLOCK)
		INNER JOIN NotificationExtra AS ne WITH (NOLOCK) ON n.NotificationID = ne.NotificationID
	WHERE ne.EventDate BETWEEN @FEventDate AND @TEventDate
		AND n.StatusID IN (
			SELECT StatusID
			FROM dbo.NotiStatus WITH (NOLOCK)
			WHERE Status IN ('Active')
		)
		AND n.NotificationType = 2 --Lap
	ORDER BY ne.EventDate
		,n.NotificationID
	OPTION (RECOMPILE)
	
	-----------------------------------------Return-------------------------------------------
	----------Paging----------
	DECLARE @RStart INT = @PageSize * (@PageIndex - 1) + 1
	DECLARE @REnd INT = @RStart + @PageSize - 1
	
	SELECT @TotalRows = ISNULL((SELECT MAX(RNo) FROM #tmpResult), 0)
	
	--get all row if invalid Paging params
	IF NOT EXISTS (SELECT 1 WHERE @RStart <= @REnd)
	BEGIN
		
		SELECT @RStart = 0
			,@REnd = @TotalRows
	END
	
	----------return----------
	SELECT @TotalRows AS TotalRows
	
	SELECT r.LAPNotiID AS NotificationID
		,CONVERT(VARCHAR, r.EventDate4GMT, 101) AS EventDate --MM/DD/YYYY
		,sj.Subject_cs + ' | ' + sj.Subject_en + ' (' + CONVERT(VARCHAR, r.EventDate4GMT, 106) + ')' AS Subject --dd Mon yyyy
		,CASE WHEN @LanguageCode = 'en' THEN r.Content_en
			ELSE r.Content_cs END AS Content
	FROM #tmpResult AS r
		OUTER APPLY OPENJSON(r.Subject) WITH (
						Subject_en NVARCHAR(300) '$.Subject_en'
						,Subject_cs NVARCHAR(300) '$.Subject_cs'
					) AS sj --OPENJSON case-sensitive
	WHERE r.RNo BETWEEN @RStart AND @REnd
		AND ISJSON(r.Subject) = 1
	ORDER BY RNo
	
	DROP TABLE #tmpResult
END