/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_PrepareGenLAP
AS
/*
	Created: 20231213@Roy
	Task: Prepare to generate message for LAP
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		Steps
			- List of DBMSG NotificationID
				+ NOT EXISTS LAP Notification
				+ Status = Sent => successful push to DBMSG
				+ Scan back only 48 hours from DBMSG NotificationID created
			- Define things need to use RemotingRef Func
		
		Output
			Dataset to get multilanguage from RemotingRef
			----|-------------------|---------------|-------------------|-------------
				|NotificationIDs	|GroupName		|RefId1				|RefId2
			----|-------------------|---------------|-------------------|-------------
				| 50				| RefResource	| ResourceCricket	| G1
				| 52,64				| RefResource	| ResourceCricket	| G2
			----|-------------------|---------------|-------------------|-------------
	
	Example:
		EXEC MessageNotification.dbo.MNC_ResultAmendment_PrepareGenLAP
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@ProcessID INT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@NotificationIDs VARCHAR(MAX)
	
	/*
		Load setting
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @ProcessID = 9 --Process_GenerateLapNoti
		
	--Insert if NOT EXISTS
	INSERT INTO LogAction (ActName)
	SELECT o.[name]
	FROM sys.objects AS o WITH (NOLOCK)
	WHERE o.[is_ms_shipped] = 0 --created by user
		AND o.[type] IN (
			'P', -- stored procedures
			'FN', -- scalar functions 
			'IF', -- inline table-valued functions
			'TF' -- table-valued functions
		)
		AND o.[name] NOT LIKE '_delete%'
		AND o.[name] NOT LIKE '[_delete%'
		AND o.[name] NOT LIKE '_DEL%'
		AND NOT EXISTS (
			SELECT 1
			FROM LogAction AS a
			WHERE a.ActName = o.[name]
		)
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @ErrLogPrefix = 'Error - '
	SELECT @InfLogPrefix = 'Info - '
	
	--check current status of generate message process
	IF NOT EXISTS (SELECT 1 FROM SystemSetting WHERE VID = @ProcessID AND VValue = 'Done') --Process_GenerateLapNoti
	BEGIN
		SELECT NULL AS NotificationIDs
			,NULL AS GroupName
			,NULL AS RefId1
			,NULL AS RefId2
		WHERE 1 = 0
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Another [Generate Lap Noti] Process(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') is still active.'
		
		RETURN
	END
	ELSE
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = 'Running'
		WHERE VID = @ProcessID
			AND VValue = 'Done'
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Start [Generate Lap Noti process - Prepare] - change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']' AS LogBef
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = @ProcessID
	END
	
	CREATE TABLE #tmpPrepareNoti (
		NotificationID INT
		,SportType SMALLINT
		,InvalidType TINYINT
	)
	
	CREATE TABLE #tmpRemotingRef (
		NotificationID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
	)
	
	/*
		Get List of Msg NotificationID which not EXISTS Lap NotificationID
			Refer to Data rule #2.Running Status Too Long.sql
	*/
	;WITH CTE_Msg AS (
		SELECT DISTINCT nMsg.NotificationID AS MsgNotiID
			,rh.SportType
		FROM Notification AS nMsg WITH (NOLOCK)
			INNER JOIN NotiMapping AS mMsg WITH (NOLOCK) ON nMsg.NotificationID = mMsg.NotificationID
			INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON mMsg.SettlementLogID = rh.SettlementLogID
		WHERE nMsg.LastModifiedTime >= DATEADD(HH, - 36, GETDATE())
			AND nMsg.NotificationType = 1 --1: Result Amendment to Msg
			AND rh.SportType = 50 --Cricket, need modify for others sport
			AND nMsg.StatusID IN (13)--Sent only successful push to DBMSG
			AND nMsg.RefID IS NOT NULL
	)
	,CTE_Lap AS (
		SELECT DISTINCT nLap.NotificationID AS LapNotiID
			,ext.MsgNotiID
		FROM Notification AS nLap WITH (NOLOCK)
			INNER JOIN NotificationExtra AS nLapEx WITH (NOLOCK) ON nLap.NotificationID = nLapEx.NotificationID
			OUTER APPLY OPENJSON(nLapEx.ExtraInfo) WITH (
					MsgNotiID VARCHAR(MAX) '$.MsgNotiID'
				) AS ext--OPENJSON case-sensitive
		WHERE nLap.LastModifiedTime >= DATEADD(HH, - 36, GETDATE())
			AND nLap.NotificationType = 2 --2: Result Amendment to LAP
	)
	INSERT INTO #tmpPrepareNoti (
		NotificationID
		,SportType
	)
	SELECT m.MsgNotiID
		,m.SportType
	FROM CTE_Msg AS m
		LEFT JOIN CTE_Lap AS l ON m.MsgNotiID = l.MsgNotiID
	WHERE l.MsgNotiID IS NULL
	
	CREATE CLUSTERED INDEX CIX_tmpPrepareNoti ON #tmpPrepareNoti(NotificationID)
	
	--validate again
	;WITH CTE_Valid AS (
		SELECT i.NotificationID
		FROM #tmpPrepareNoti AS i
			INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON i.NotificationID = nt.NotificationID --must EXISTS Target
			INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site AND s.isDeposit = 1 --deposit user
		GROUP BY i.NotificationID
	)
	DELETE t
	FROM #tmpPrepareNoti AS t
		LEFT JOIN CTE_Valid AS v ON t.NotificationID = v.NotificationID
	WHERE v.NotificationID IS NULL
	
	--verify AffectedResult
	UPDATE n
	SET n.InvalidType = (CASE WHEN ext.AffectedResult IS NULL THEN 1 ELSE 0 END)
	FROM #tmpPrepareNoti AS n
		LEFT JOIN NotificationExtra AS ne WITH (NOLOCK) ON n.NotificationID = ne.NotificationID
		OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
					AffectedResult NVARCHAR(MAX) '$.AffectedResult' AS JSON
				) AS ext--OPENJSON case-sensitive
	WHERE ISJSON(ne.ExtraInfo) = 1
	
	IF EXISTS (
		SELECT 1
		FROM #tmpPrepareNoti
		WHERE InvalidType = 1
	)
	BEGIN
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT NotificationID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + '[Generate Lap Noti process - Prepare] - Missing NotificationExtra.ExtraInfo@AffectedResult'
			FROM #tmpPrepareNoti
			WHERE InvalidType = 1
			ORDER BY NotificationID
	END
	
	---write log
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Debug - [Generate Lap Noti process - Prepare]'
						+ ' - Msg List to Generate Lap ('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT NotificationID
											FROM #tmpPrepareNoti
											ORDER BY NotificationID
											FOR JSON PATH
										))
									),'NO ROW') + ')'
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	/*
		build things to get from RemotingRef
		
		Currently, no need info from @JSRemotingRef
			=> only FW list of NotificationIDs for next step
	*/
	INSERT INTO #tmpRemotingRef (
		NotificationID
		,GroupName
		,RefId1
		,RefId2
	)
	SELECT DISTINCT n.NotificationID
		,'EventInfo' AS GroupName
		,'SportType' AS RefId1
		,SportType AS RefId2
	FROM #tmpPrepareNoti AS n
	WHERE InvalidType = 0
	
	--return for RemotingRef
	;WITH CTE_Ref AS (
		SELECT DISTINCT NotificationID
			,GroupName
			,RefId1
			,RefId2
		FROM #tmpRemotingRef
	)
	SELECT STRING_AGG(CONVERT(VARCHAR(MAX),rf.NotificationID),',') AS NotificationIDs
		,rf.GroupName
		,rf.RefId1
		,rf.RefId2
	FROM CTE_Ref AS rf
	GROUP BY rf.GroupName
		,rf.RefId1
		,rf.RefId2
	
	--Mark completed process
	IF NOT EXISTS (SELECT 1 FROM #tmpRemotingRef)
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = 'Done'
		WHERE VID = @ProcessID
			AND VValue = 'Running'
	
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Completed [Generate Lap Noti process - Prepare] - change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']' AS LogBef
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = @ProcessID
	END
	
	----------------------
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT NotificationID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + '[Generate Lap Noti process - Prepare] - Completed'
						+ ' - Return('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT STRING_AGG(CONVERT(VARCHAR(MAX),rf.NotificationID),',') AS NotificationIDs
											,rf.GroupName
											,rf.RefId1
											,rf.RefId2
										FROM (
											SELECT DISTINCT NotificationID
												,GroupName
												,RefId1
												,RefId2
											FROM #tmpRemotingRef
										) AS rf
										GROUP BY rf.GroupName
											,rf.RefId1
											,rf.RefId2
										FOR JSON PATH
									))
								),'NO ROW') + ')'
		FROM #tmpRemotingRef
	
	DROP TABLE #tmpPrepareNoti
	DROP TABLE #tmpRemotingRef
END
