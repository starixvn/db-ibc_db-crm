/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_lap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_AdmNotificationSel
	@FEventDate DATE
	,@TEventDate DATE
	,@AgentList VARCHAR(MAX)
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
		20240610@Luke: LAP - Enhance Result Amendment [Redmine: #199443]
	
	Param's Explanation:
		@FEventDate, @TEventDate: Date range to view list notification [Match.EventDate]
		@LanguageCode:
						zh-CN: Simplified Chinese
						en: English
		@AgentList: List agent to view notification
		@PageSize ,@PageIndex: handle paging
	Example:
		EXEC MessageNotification.dbo.Lrf_AdmNotificationSel
			@FEventDate = '2024-06-01'
			,@TEventDate = '2024-06-11'
			,@AgentList = '<ROOT><Agent AgentId="20121327"/><Agent AgentId="119277091"/></ROOT>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @TotalRows INT = 0
	DECLARE @DocHandler INT

	CREATE TABLE #AgentIDs (AgentId INT)

 	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
 	
 	INSERT INTO #AgentIDs (AgentId)
 	SELECT DISTINCT Data.AgentId
 	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT) AS Data 
	
	CREATE UNIQUE CLUSTERED INDEX CIX_AgentIDs ON #AgentIDs (AgentId)
	
 	EXEC sp_xml_removedocument @DocHandler

	CREATE TABLE #NotiIDs (NotificationId INT)

	INSERT INTO #NotiIDs (NotificationId)
	SELECT DISTINCT e.NotificationID
	FROM dbo.NotificationExtra e WITH (NOLOCK)
		INNER JOIN dbo.NotificationTarget AS t WITH (NOLOCK) ON e.NotificationID = t.NotificationID
	WHERE e.EventDate BETWEEN @FEventDate AND @TEventDate
		AND EXISTS (
			SELECT 1
			FROM #AgentIDs AS a
			WHERE a.AgentId = t.TargetID
		)
	OPTION (RECOMPILE)
	
	CREATE UNIQUE CLUSTERED INDEX CIX_NotiIDs ON #NotiIDs (NotificationId)

	CREATE TABLE #tmpResult (
		RNo INT IDENTITY(1, 1) PRIMARY KEY
		,LAPNotiID INT
		,EventDate4GMT DATE
		,Title NVARCHAR(1000)
		,Content_en NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
		,InsertedTime DATETIME
	)
	
	/*****************************************   APPLY filter criterias   *********************************************************/
	
	--Get LAP Notifications
	INSERT INTO #tmpResult (
		LAPNotiID
		,EventDate4GMT
		,Title
		,Content_en
		,Content_cs
		,InsertedTime
	)
	SELECT DISTINCT n.NotificationID
		,ne.EventDate
		,n.Subject
		,n.Content_en
		,n.Content_cs
		,n.InsertedTime
	FROM #NotiIDs AS nd
		INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON nd.NotificationId = n.NotificationID
		INNER JOIN dbo.NotificationExtra AS ne WITH (NOLOCK) ON nd.NotificationId = ne.NotificationID
	WHERE ne.EventDate BETWEEN @FEventDate AND @TEventDate
		AND n.StatusID IN (
			SELECT StatusID
			FROM dbo.NotiStatus WITH (NOLOCK)
			WHERE Status IN ('Active')
		)
		AND n.NotificationType = 2 --Lap
	ORDER BY ne.EventDate
		,n.NotificationID
	
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

	IF @LanguageCode = 'en'
	BEGIN
		SELECT r.LAPNotiID AS NotiID
			,CONVERT(VARCHAR, r.EventDate4GMT, 101) AS EventDate --MM/DD/YYYY
			,r.Title 
			,r.Content_en AS Content
			,r.InsertedTime
		FROM #tmpResult AS r
		WHERE r.RNo BETWEEN @RStart AND @REnd
		ORDER BY RNo
	END
	ELSE
	BEGIN
		SELECT r.LAPNotiID AS NotiID
			,CONVERT(VARCHAR, r.EventDate4GMT, 101) AS EventDate --MM/DD/YYYY
			,r.Title
			,r.Content_cs AS Content
			,r.InsertedTime
		FROM #tmpResult AS r
		WHERE r.RNo BETWEEN @RStart AND @REnd
		ORDER BY RNo
	END

	SELECT @TotalRows AS TotalRows
	
	DROP TABLE #tmpResult, #NotiIDs, #AgentIDs
END
