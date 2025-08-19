/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_PrepareGenLAP
	@Environment VARCHAR(20)
AS
/*
	Created: 20231213@Roy
	Task: Prepare to generate message for LAP
	DB: DBCRM.MessageNotification
	Revisions:
		- 20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
		- 20241107@Tacy: CRM - Implement Message Notifications Center for Result Amendment of basketball and E-Sports [#212035]
		- 20250829@Dave: MNC - Auto Result Amendment for Fast Market [RedmineID: #230646]

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
		,@PRODIncludeTest BIT = 0
		,@IsTestFlag BIT
	
	/*
		Load setting
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
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
	
	SELECT @PRODIncludeTest = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --IncludeTestMatch
	
	IF @Environment = 'LIVE'
	BEGIN
		SELECT @ProcessID = 9 --GenerateLAPNotifService
		SELECT @ErrLogPrefix = 'Error - [GenerateLAPNotifService - Prepare] - '
		SELECT @InfLogPrefix = 'Info - [GenerateLAPNotifService - Prepare] - '
	END
	ELSE
	BEGIN
		SELECT @ProcessID = 14 --UAT_GenerateLAPNotifService
		SELECT @ErrLogPrefix = 'Error - [UAT_GenerateLAPNotifService - Prepare] - '
		SELECT @InfLogPrefix = 'Info - [UAT_GenerateLAPNotifService - Prepare] - '
		
		SELECT @Environment = ISNULL(@Environment,'UAT')
	END
	
	/*
		Filter data by IncludeTestMatch
			If IncludeTestMatch = ON
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If IncludeTestMatch = OFF
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
	*/
	IF @PRODIncludeTest = 1 AND @Environment = 'UAT' --no action (RETURN)
	BEGIN
		SELECT NULL AS NotificationIDs
			,NULL AS GroupName
			,NULL AS RefId1
			,NULL AS RefId2
		WHERE 1 = 0
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'NO Action for IncludeTestMatch = ON AND Environment = UAT')
		
		RETURN
	END
	ELSE IF @PRODIncludeTest = 0 AND @Environment = 'LIVE' --REAL data only
	BEGIN
		SET @IsTestFlag = 0
	END
	ELSE IF @PRODIncludeTest = 0 AND @Environment = 'UAT' --TEST data only
	BEGIN
		SET @IsTestFlag = 1
	END
	ELSE --both REAL & TEST
	BEGIN
		SET @IsTestFlag = NULL
	END
	
	--check current status of generate message process
	IF NOT EXISTS (SELECT 1 FROM SystemSetting WHERE VID = @ProcessID AND VValue = 'Done') --Process_GenerateLapNoti
	BEGIN
		SELECT NULL AS NotificationIDs
			,NULL AS GroupName
			,NULL AS RefId1
			,NULL AS RefId2
		WHERE 1 = 0
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'Another Process(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') is still active.')
		
		RETURN
	END
	ELSE
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = 'Running'
		WHERE VID = @ProcessID
			AND VValue = 'Done'
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']') AS LogBef
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = @ProcessID
	END
	
	CREATE TABLE #tmpPrepareNoti (
		NotificationID	INT
		,SportType		SMALLINT
		,InvalidType	TINYINT
		,ActionType		TINYINT
		,AffectedResult	NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpRemotingRef (
		NotificationID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
	)

	CREATE TABLE #tmpAffectedResult(
		NotificationID	INT,
		ResourceID INT,
		Pos TINYINT,
		ActionTypeOnPos TINYINT,
		ActualValue_en NVARCHAR(100),
		WrongValue_en NVARCHAR(100)
	);
	
	/*
		Get List of Msg NotificationID which not EXISTS Lap NotificationID
			Refer to Data rule #2.Running Status Too Long.sql
	*/
	;WITH CTE_Msg AS (
		SELECT DISTINCT nMsg.NotificationID AS MsgNotiID
			,nMsg.RefID AS MessageID
			,rh.SportType
			,rh.ActionType
		FROM Notification AS nMsg WITH (NOLOCK)
			INNER JOIN NotiMapping AS mMsg WITH (NOLOCK) ON nMsg.NotificationID = mMsg.NotificationID
			INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON mMsg.SettlementLogID = rh.SettlementLogID
			CROSS APPLY dbo.f_MNC_ResultAmendment_SportSel(rh.SportType, @Environment) s
		WHERE nMsg.LastModifiedTime >= DATEADD(HH, - 36, GETDATE())
			AND nMsg.NotificationType = 1 --1: Result Amendment to Msg
			AND nMsg.StatusID IN (13)--Sent only successful push to DBMSG
			AND nMsg.RefID IS NOT NULL
			AND (
				@IsTestFlag IS NULL
				OR rh.IsTest = @IsTestFlag
			) --filter by Environment/IncludeTestMatch
	)
	,CTE_Lap AS (
		SELECT DISTINCT nLap.RefID AS MessageID
		FROM Notification AS nLap WITH (NOLOCK)
		WHERE nLap.LastModifiedTime >= DATEADD(HH, - 36, GETDATE())
			AND nLap.NotificationType = 2 --2: Result Amendment to LAP
	)
	INSERT INTO #tmpPrepareNoti (
		NotificationID
		,SportType
		,ActionType
	)
	SELECT m.MsgNotiID
		,m.SportType
		,m.ActionType
	FROM CTE_Msg AS m
		LEFT JOIN CTE_Lap AS l ON m.MessageID = l.MessageID
	WHERE l.MessageID IS NULL
	
	CREATE CLUSTERED INDEX CIX_tmpPrepareNoti ON #tmpPrepareNoti(NotificationID)
	
	--validate again
	;WITH CTE_Valid AS (
		SELECT i.NotificationID
		FROM #tmpPrepareNoti AS i
		WHERE EXISTS (
			SELECT 1
			FROM NotificationTarget AS nt WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site AND s.isDeposit = 1 --deposit user
			WHERE i.NotificationID = nt.NotificationID --must EXISTS Target
				AND s.site IS NOT NULL --EXISTS [deposit] Target
		)
		GROUP BY i.NotificationID
	)
	DELETE t
	FROM #tmpPrepareNoti AS t
		LEFT JOIN CTE_Valid AS v ON t.NotificationID = v.NotificationID
	WHERE v.NotificationID IS NULL
	
	--verify AffectedResult
	UPDATE n
	SET n.InvalidType = (CASE WHEN ext.AffectedResult IS NULL THEN 1 ELSE 0 END)
		,n.AffectedResult = IIF(ActionType = 5, ext.AffectedResult, NULL) /*5: Fast Market*/
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
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT NotificationID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'Missing NotificationExtra.ExtraInfo@AffectedResult')
			FROM #tmpPrepareNoti
			WHERE InvalidType = 1
			ORDER BY NotificationID
	END
	
	---write log
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Debug - Msg List to Generate Lap ('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT NotificationID
											FROM #tmpPrepareNoti
											ORDER BY NotificationID
											FOR JSON PATH
										))
									),'NO ROW') + ')')
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
	WHERE InvalidType = 0;

	/*
		build things to get from RemotingRef
			+ ResultSettlement for SportType (resourceID) in (221, 222, 223, 224, 226, 227) - FastMarket
	*/
	INSERT INTO #tmpAffectedResult(
		NotificationID
		,ResourceID
		,Pos
		,ActionTypeOnPos
		,ActualValue_en
		,WrongValue_en
	)
	SELECT 
		n.NotificationID
		,ar.ResourceID
		,ar.Pos
		,ar.ActionTypeOnPos
		,ar.ActualValue_en
		,ar.WrongValue_en
	FROM #tmpPrepareNoti AS n
		CROSS APPLY OPENJSON(n.AffectedResult) WITH (
					ResourceID INT '$.ResourceID'
					,Pos TINYINT '$.Pos'
					,ActionTypeOnPos TINYINT '$.ActionTypeOnPos'
					,ActualValue_en NVARCHAR(100) '$.ActualValue_en'
					,WrongValue_en NVARCHAR(100) '$.WrongValue_en'
				) AS ar/*OPENJSON case-sensitive*/
	WHERE n.InvalidType = 0
		AND n.ActionType = 5 /*5: Fast Market*/
		AND ISJSON(n.AffectedResult) = 1
		AND ar.ResourceID IN (221, 222, 223, 224, 226, 227, 225) /*Fast Market*/;
		
	/*write log for AffectedResult*/
	IF EXISTS (
		SELECT 1
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 13 /*LogMode*/
			AND VValue = 'Debug'
	)
	BEGIN
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Debug - AffectedResult ('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
												SELECT NotificationID
													,ResourceID
													,Pos
													,ActionTypeOnPos
													,ActualValue_en
													,WrongValue_en
												FROM #tmpAffectedResult
												ORDER BY NotificationID, ResourceID, Pos
												FOR JSON PATH
											))
										),'NO ROW') + ')');
	END

	IF EXISTS ( SELECT TOP(1) 1 FROM #tmpAffectedResult WHERE ResourceID IN (225))
	BEGIN

		WITH tmp_ListResults AS (
			SELECT 
				NotificationID,
				ActualValue_en AS RefId2
			FROM #tmpAffectedResult
			WHERE ActionTypeOnPos IN (1, 3)
				AND ResourceID IN (225)
			UNION ALL

			SELECT 
				NotificationID,
				WrongValue_en
			FROM #tmpAffectedResult
			WHERE ActionTypeOnPos IN (1, 2)
				AND ResourceID IN (225)
		)
		INSERT INTO #tmpRemotingRef (
			NotificationID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT 
			r.NotificationID,
			'RefResource' AS GroupName
			,'ResultSettlement' AS RefId1
			,CASE r.RefId2 
				WHEN '1' THEN 'N' 
				WHEN '44' THEN 'Y'
			END AS RefId2
		FROM tmp_ListResults AS r
		;

		DELETE #tmpAffectedResult WHERE ResourceID IN (225);

	END

	IF EXISTS ( SELECT TOP(1) 1 FROM #tmpAffectedResult)
	BEGIN

		WITH Tally AS (
			SELECT v.n
			FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7)) v(n)
		),
		tmp_ListResults AS (
			SELECT 
				NotificationID,
				CAST(ActualValue_en AS INT) AS num
			FROM #tmpAffectedResult
			WHERE ActionTypeOnPos IN (1, 3)
			UNION ALL

			SELECT 
				NotificationID,
				CAST(WrongValue_en AS INT) AS num
			FROM #tmpAffectedResult
			WHERE ActionTypeOnPos IN (1, 2)
		),
		tmp_listRefId2 AS (
			SELECT DISTINCT 
				nbs.NotificationID,
				'b' + CAST(t.n AS VARCHAR(10)) AS BitPosition
			FROM Tally AS t
			INNER JOIN tmp_ListResults AS nbs
				ON (nbs.num & CAST(POWER(2, t.n) AS TINYINT)) <> 0
		)
		INSERT INTO #tmpRemotingRef (
			NotificationID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT 
			r.NotificationID,
			'RefResource' AS GroupName
			,'ResultSettlement' AS RefId1
			,r.BitPosition AS RefId2
		FROM tmp_listRefId2 AS r
		;

	END
	
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
	
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Completed - Change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']') AS LogBef
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = @ProcessID
	END
	
	----------------------
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT NotificationID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Completed - Return('
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
								),'NO ROW') + ')')
		FROM #tmpRemotingRef
	
	DROP TABLE #tmpPrepareNoti
	DROP TABLE #tmpRemotingRef
	DROP TABLE #tmpAffectedResult
END
