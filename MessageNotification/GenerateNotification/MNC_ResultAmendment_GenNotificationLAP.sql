/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_GenNotificationLAP
	@JSRemotingRef NVARCHAR(MAX)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: generate message
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@Environment
			If UATMode = OFF
				+ @Environment = LIVE => handle all data
				+ @Environment = UAT => return
			If UATMode = ON
				+ @Environment = LIVE => handle REAL data
				+ @Environment = UAT => handle TEST data
		
		Input
			@JSRemotingRef NVARCHAR(MAX) = N'
				[
					{"SettlementLogIDs":"81","GroupName":"EventInfo","RefId1":"LeagueID","RefId2":"89623","RefValueEN":"Virtual Soccer Euro Cup","RefValueCH":"虛擬足球歐洲盃","RefValueCS":"虚拟足球欧洲杯"},
					{"SettlementLogIDs":"81,79,78","GroupName":"EventInfo","RefId1":"SportType","RefId2":"50","RefValueEN":"Cricket","RefValueCH":"板球","RefValueCS":"板球"},
					{"SettlementLogIDs":"81","GroupName":"EventInfo","RefId1":"TeamID","RefId2":"674489","RefValueEN":"England","RefValueCH":"英格兰","RefValueCS":"英格兰"},
					{"SettlementLogIDs":"81","GroupName":"EventInfo","RefId1":"TeamID","RefId2":"674497","RefValueEN":"Germany","RefValueCH":"德国","RefValueCS":"德国"},
					{"SettlementLogIDs":"52,64","GroupName":"EventInfo","RefId1":"TeamID","RefId2":"953783","RefValueEN":"Bangalore (V)","RefValueCH":"邦加羅爾虛擬隊","RefValueCS":"邦加罗尔虚拟队"},
					{"SettlementLogIDs":"173,83,84","GroupName":"RefResource","RefId1":"ResourceCricket","RefId2":"9442","RefValueEN":"@G Highest Opening Partnership","RefValueCH":"@G搭檔開場最高得分盤","RefValueCS":"@G搭档开场最高得分盘"}
				]'
		Output
			None
		Target
			NotiMapping
			Notification
			NotificationTarget
			NotificationExtra
		Steps
			#1.Parse inputed JSON
			#2.Prepare Param based on NotiTemplate
			#3.Insert Notification LAP
	Example:
		EXEC MessageNotification.dbo.MNC_ResultAmendment_GenNotificationLAP @JSRemotingRef
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@StsNew TINYINT
		,@StsGenerating TINYINT
		,@SettlIDs NVARCHAR(MAX)
		,@JSResource NVARCHAR(MAX)
		,@ErrLogPrefix NVARCHAR(150) = 'Error - '
		,@InfLogPrefix NVARCHAR(150) = 'Info - '
		,@iLoop INT
		,@Refund_en NVARCHAR(20) = 'Refund'
		,@Refund_ch NVARCHAR(20) = N'退款'
		,@Refund_cs NVARCHAR(20) = N'退款'
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @StsGenerating = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Generating'
	-----------------------------------------------
	CREATE TABLE #tmpRemotingRef (
		Msg_NotiID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
		,RefValueEN NVARCHAR(500)
		,RefValueCH NVARCHAR(500)
		,RefValueCS NVARCHAR(500)
	)

	CREATE TABLE #tmpExtraInfo (
		Msg_NotiID INT
		,SettlementLogID INT
		,ResourceID VARCHAR(50)
		,ReCalc DATETIME
		,Calc DATETIME
		,AmendedCnt TINYINT
		,ActionType TINYINT
		,GameSession TINYINT
	)

	CREATE TABLE #tmpParsedResult (
		SettlementLogID INT
		,AmendInfo VARCHAR(50)
		,ResourceID VARCHAR(50)
		,RefBettypeID VARCHAR(50)
		,HomeValue VARCHAR(50)
		,AwayValue VARCHAR(50)
		,OtherInfo VARCHAR(200)
		,TeamIDs VARCHAR(200)
		,G VARCHAR(50)
		,X VARCHAR(50)
		,Y VARCHAR(50)
	)
	
	CREATE TABLE #tmpBuildResult (
		SettlementLogID INT
		,ResourceID VARCHAR(50)
		,OtherInfo VARCHAR(200)
		,G VARCHAR(50)
		,X VARCHAR(50)
		,Y VARCHAR(50)
		,ResultName_en NVARCHAR(4000)
		,ResultName_ch NVARCHAR(4000)
		,ResultName_cs NVARCHAR(4000)
	)
	
	CREATE TABLE #tmpTemplateDetl (
		Msg_NotiID INT
		,RequiredParamID INT
		,RequiredParam VARCHAR(50)
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	
	CREATE TABLE #tmpSettlLog (
		Msg_NotiID INT
		,LogType VARCHAR(50)
		,LogDateTime DATETIME
		,LogDateTime_en NVARCHAR(50)
		,LogDateTime_ch NVARCHAR(50)
		,LogDateTime_cs NVARCHAR(50)
		,ResultName_en NVARCHAR(4000)
		,ResultName_ch NVARCHAR(4000)
		,ResultName_cs NVARCHAR(4000)
	)
	
	CREATE TABLE #tmpInsertedNoti (
		Lap_NotiID INT NOT NULL
		,Msg_NotiID INT NOT NULL
	)
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpInsertedNoti ON #tmpInsertedNoti (Lap_NotiID)
	
	CREATE TABLE #tmpNoti (
		Msg_NotiID INT NOT NULL
		,TemplateID INT NOT NULL
		,Subject NVARCHAR(1000)
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	
	CREATE TABLE #tmpNotiTarget (
		Lap_NotiID INT
		,TargetID INT
		,TargetSite NVARCHAR(50)
		,CustID INT
		,TransID BIGINT
	)
	
	/*
		#1 - Start to Parse inputed JSON
	*/
	BEGIN TRY
		INSERT INTO #tmpRemotingRef(
			Msg_NotiID
			,GroupName
			,RefId1
			,RefId2
			,RefValueEN
			,RefValueCH
			,RefValueCS
		)
		SELECT DISTINCT value AS Msg_NotiID
			,GroupName
			,RefId1
			,RefId2
			,RefValueEN
			,RefValueCH
			,RefValueCS
		FROM OPENJSON(@JSRemotingRef) WITH (
				NotificationIDs VARCHAR(MAX) '$.NotificationIDs'
				,GroupName VARCHAR(50) '$.GroupName'
				,RefId1 VARCHAR(50) '$.RefId1'
				,RefId2 VARCHAR(50) '$.RefId2'
				,RefValueEN NVARCHAR(500) '$.RefValueEN'
				,RefValueCH NVARCHAR(500) '$.RefValueCH'
				,RefValueCS NVARCHAR(500) '$.RefValueCS'
			)--OPENJSON case-sensitive
			CROSS APPLY STRING_SPLIT(NotificationIDs, ',')
		CREATE CLUSTERED INDEX CIX_tmpRemotingRef ON #tmpRemotingRef (Msg_NotiID)
		
		;WITH CTE_Ext AS (
			SELECT rf.Msg_NotiID
				,rh.SettlementLogID
				,TRY_CONVERT(XML, rh.ExtraInfo) AS ExtraInfoXML
			FROM #tmpRemotingRef AS rf
				INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON rf.Msg_NotiID = nm.NotificationID
				INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
		)
		INSERT INTO #tmpExtraInfo (
			Msg_NotiID
			,SettlementLogID
			,ResourceID
			,ReCalc
			,Calc
			,AmendedCnt
			,ActionType
			,GameSession
		)
		SELECT DISTINCT c.Msg_NotiID
			,c.SettlementLogID
			,NULLIF(TRIM(rh.ex.value('@Id', 'VARCHAR(50)')), '') AS ResourceID
			,rh.ex.value('@ReCalc', 'DATETIME') AS ReCalc
			,rh.ex.value('@Calc', 'DATETIME') AS Calc
			,ext.AmendedCnt
			,ext.ActionType
			,ext.GameSession
		FROM CTE_Ext AS c
			CROSS APPLY c.ExtraInfoXML.nodes('root/r') rh(ex)
			INNER JOIN NotificationExtra AS ne WITH (NOLOCK) ON c.Msg_NotiID = ne.NotificationID
			CROSS APPLY OPENJSON(ne.ExtraInfo) WITH (
							AmendedCnt TINYINT '$.AmendedCnt'
							,ActionType TINYINT '$.ActionType'
							,GameSession TINYINT '$.GameSession'
						) AS ext --OPENJSON case-sensitive
		WHERE NULLIF(TRIM(rh.ex.value('@Id', 'VARCHAR(50)')), '') IS NOT NULL
		CREATE CLUSTERED INDEX CIX_tmpExtraInfo ON #tmpExtraInfo (Msg_NotiID, SettlementLogID)
		
		;WITH CTE_LAP AS (
			SELECT DISTINCT ntc.NotificationID
			FROM NotificationTarget AS ntc WITH (NOLOCK)
				INNER JOIN #tmpExtraInfo AS ex ON ntc.NotificationID = ex.Msg_NotiID
				INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON ntc.TargetSite = s.site AND s.isDeposit = 1 --deposit user
				CROSS APPLY OPENJSON(ntc.ExtraInfo) WITH (
					TransID BIGINT '$.TransID'
				) AS t--OPENJSON case-sensitive
			WHERE t.TransID IS NOT NULL
		)
		INSERT INTO #tmpNoti (
			Msg_NotiID 
			,TemplateID
			,Content_en
			,Content_ch
			,Content_cs
		)
		SELECT DISTINCT ex.Msg_NotiID
			,tp.TemplateID
			,tp.Content_en
			,tp.Content_ch
			,tp.Content_cs
		FROM #tmpExtraInfo AS ex
			INNER JOIN CTE_LAP AS l ON ex.Msg_NotiID = l.NotificationID
			INNER JOIN Notification AS n WITH (NOLOCK) ON ex.Msg_NotiID = n.NotificationID
			,NotiTemplate AS tp WITH (NOLOCK) --currently, only have 1 message TemplateID for LAP
		WHERE tp.TemplateID = 6--Cricket Result Amendment - Notification for LAP
			AND n.NotificationType = 1 --Result Amendment to Msg
		CREATE UNIQUE CLUSTERED INDEX CIX_tmpNoti ON #tmpNoti (Msg_NotiID)
		/*
			Parse data from ActualResult / WrongResult
				#tmpParsedResult
		*/
		SELECT @SettlIDs = STRING_AGG(CONVERT(NVARCHAR(MAX),ex.SettlementLogID),',')
		FROM #tmpExtraInfo AS ex
			INNER JOIN #tmpNoti AS n ON ex.Msg_NotiID = n.Msg_NotiID
		
		EXEC MNC_ResultAmendment_JSParseResult
			@SettlementLogIDs = @SettlIDs
			,@ParseAmendInfo = 'ActualResult,WrongResult'
			,@ParseTo = 'RawData'
			,@OutJSResource = @JSResource OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
		
		INSERT INTO #tmpParsedResult (
			SettlementLogID
			,AmendInfo
			,ResourceID
			,RefBettypeID
			,HomeValue
			,AwayValue
			,OtherInfo
			,TeamIDs
			,G
			,X
			,Y
		)
		SELECT DISTINCT SettlementLogID
			,AmendInfo
			,ResourceID
			,RefBettypeID
			,HomeValue
			,AwayValue
			,OtherInfo
			,TeamIDs
			,G
			,X
			,Y
		FROM OPENJSON(@JSResource) WITH (
				SettlementLogID INT '$.SettlementLogID'
				,AmendInfo VARCHAR(50) '$.AmendInfo'
				,ResourceID VARCHAR(50) '$.ResourceID'
				,RefBettypeID VARCHAR(50) '$.RefBettypeID'
				,HomeValue VARCHAR(50) '$.HomeValue'
				,AwayValue VARCHAR(50) '$.AwayValue'
				,OtherInfo VARCHAR(200) '$.OtherInfo'
				,TeamIDs VARCHAR(200) '$.TeamIDs'
				,G VARCHAR(50) '$.G'
				,X VARCHAR(50) '$.X'
				,Y VARCHAR(50) '$.Y'
			)--OPENJSON case-sensitive
		WHERE SettlementLogID IS NOT NULL
			AND ResourceID IS NOT NULL
		CREATE CLUSTERED INDEX CIX_tmpParsedResult ON #tmpParsedResult (SettlementLogID)
		
		--write log--
		;WITH CTE_ValidNoti AS (
			SELECT DISTINCT n.Msg_NotiID
			FROM #tmpExtraInfo AS ex
			INNER JOIN #tmpNoti AS n ON ex.Msg_NotiID = n.Msg_NotiID
			INNER JOIN #tmpParsedResult AS rs ON ex.SettlementLogID = rs.SettlementLogID
		)
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT rf.Msg_NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Msg_NotiID - FAILED while parsing inputed JSON to create NotificationID LAP - '
					+ '@JSRemotingRef = ' + ISNULL(@JSRemotingRef,'NULL')
					+ ', @SettlIDs = ' + ISNULL(@SettlIDs,'NULL')
					+ ', @JSResource = ' + ISNULL(@JSResource,'NULL')
		FROM #tmpRemotingRef AS rf
			LEFT JOIN CTE_ValidNoti AS v ON rf.Msg_NotiID = v.Msg_NotiID
		WHERE v.Msg_NotiID IS NULL
		ORDER BY rf.Msg_NotiID
		
		--delete invalid Msg_NotiID
		DELETE FROM #tmpNoti
		WHERE Msg_NotiID NOT IN (
			SELECT DISTINCT n.Msg_NotiID
			FROM #tmpExtraInfo AS ex
			INNER JOIN #tmpNoti AS n ON ex.Msg_NotiID = n.Msg_NotiID
			INNER JOIN #tmpParsedResult AS rs ON ex.SettlementLogID = rs.SettlementLogID
		)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while parsing inputed JSON to create NotificationID LAP - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT DISTINCT value
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Msg_NotiID - FAILED while parsing inputed JSON to create NotificationID LAP - '
					+ '@JSRemotingRef = (' + ISNULL(@JSRemotingRef,'NULL') + ')'
					+ ', @SettlIDs = (' + ISNULL(@SettlIDs,'NULL') + ')'
					+ ', @JSResource = (' + ISNULL(@JSResource,'NULL') + ')'
					+ ', ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		FROM OPENJSON(@JSRemotingRef) WITH (
				NotificationIDs VARCHAR(MAX) '$.NotificationIDs'
			)--OPENJSON case-sensitive
			CROSS APPLY STRING_SPLIT(NotificationIDs, ',') AS n
	END CATCH
	
	/*
		#2 - Start to Prepare Param based on NotiTemplate
	*/
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpNoti)
	BEGIN TRY
		;WITH CTE_ParseParam AS (
			SELECT DISTINCT TRIM(rq.value) AS RequiredParam
			FROM #tmpNoti AS n
				INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID
				CROSS APPLY STRING_SPLIT(tp.RequiredParams, ',') AS rq
			WHERE ISNULL(TRIM(rq.value),'') <> ''
		)
		,CTE_Param AS (
			SELECT RequiredParam
				,ROW_NUMBER() OVER (ORDER BY RequiredParam ) AS RequiredParamID --use for loop
			FROM CTE_ParseParam
		)
		INSERT INTO #tmpTemplateDetl (
			Msg_NotiID
			,RequiredParamID
			,RequiredParam
		)
		SELECT DISTINCT n.Msg_NotiID
			,r.RequiredParamID
			,r.RequiredParam
		FROM #tmpNoti AS n
			INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID--re-join to make sure [1 RequiredParamID] : [1 RequiredParam]
			CROSS APPLY STRING_SPLIT(tp.RequiredParams, ',') AS rq
			INNER JOIN CTE_Param AS r ON TRIM(rq.value) = r.RequiredParam
		
		/*
			----------{match_name}----------
			Sportsbook and Bet Builder: Hometeam -vs- Awayteam
			Number Game: [Sport] No. + Matchcode
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{match_name}')
		BEGIN
			;WITH CTE_Extra AS (
				SELECT DISTINCT n.Msg_NotiID
					,m.HomeNameEN
					,m.HomeNameCH
					,m.HomeNameCS
					,m.AwayNameEN
					,m.AwayNameCH
					,m.AwayNameCS
					,m.NeutralEN
					,m.NeutralCH
					,m.NeutralCS
				FROM #tmpNoti AS n
					INNER JOIN NotificationExtra AS ex WITH (NOLOCK) ON n.Msg_NotiID = ex.NotificationID
					CROSS APPLY OPENJSON(ex.ExtraInfo) WITH (
							HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,HomeNameCH NVARCHAR(500) '$.HomeNameCH'
							,HomeNameCS NVARCHAR(500) '$.HomeNameCS'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
							,AwayNameCH NVARCHAR(500) '$.AwayNameCH'
							,AwayNameCS NVARCHAR(500) '$.AwayNameCS'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,NeutralCH NVARCHAR(10) '$.NeutralCH'
							,NeutralCS NVARCHAR(10) '$.NeutralCS'
						) AS m--OPENJSON case-sensitive
			)
			UPDATE tp
			SET tp.Content_en = ex.HomeNameEN + ISNULL(' ' + ex.NeutralEN,'') + ' -vs- ' + ex.AwayNameEN
				,tp.Content_ch = ex.HomeNameCH + ISNULL(' ' + ex.NeutralCH,'') + ' -vs- ' + ex.AwayNameCH
				,tp.Content_cs = ex.AwayNameCS + ISNULL(' ' + ex.NeutralCS,'') + ' -vs- ' + ex.AwayNameCS
			FROM #tmpTemplateDetl AS tp
				INNER JOIN CTE_Extra AS ex ON tp.Msg_NotiID = ex.Msg_NotiID
			WHERE tp.RequiredParam = '{match_name}'
		END
	
		/*
			----------{league_name}----------
			The NotificationExtra handle for Non-Saba league name
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{league_name}')
		BEGIN
			;WITH CTE_Extra AS (
				SELECT DISTINCT n.Msg_NotiID
					,l.LeagueNameEN
					,l.LeagueNameCS
					,l.LeagueNameCH
				FROM #tmpNoti AS n
					INNER JOIN NotificationExtra AS ex WITH (NOLOCK) ON n.Msg_NotiID = ex.NotificationID
					CROSS APPLY OPENJSON(ex.ExtraInfo) WITH (
							LeagueNameEN NVARCHAR(500) '$.LeagueNameEN'
							,LeagueNameCS NVARCHAR(500) '$.LeagueNameCS'
							,LeagueNameCH NVARCHAR(500) '$.LeagueNameCH'
						) AS l--OPENJSON case-sensitive
			)
			UPDATE tp
			SET tp.Content_en = ex.LeagueNameEN
				,tp.Content_ch = ex.LeagueNameCS
				,tp.Content_cs = ex.LeagueNameCH
			FROM #tmpTemplateDetl AS tp
				INNER JOIN CTE_Extra AS ex ON tp.Msg_NotiID = ex.Msg_NotiID
			WHERE tp.RequiredParam = '{league_name}'
		END
	
		/*
			----------{event_date}----------
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{event_date}')
		BEGIN
			UPDATE tp
			SET tp.Content_en = CONVERT(VARCHAR(5),ex.EventDate,103)
				,tp.Content_ch = CONVERT(VARCHAR(5),ex.EventDate,103)
				,tp.Content_cs = CONVERT(VARCHAR(5),ex.EventDate,103)
			FROM #tmpTemplateDetl AS tp
				INNER JOIN NotificationExtra AS ex WITH (NOLOCK) ON tp.Msg_NotiID = ex.NotificationID
			WHERE tp.RequiredParam = '{event_date}'
		END
	
		/*
			----------{notification}----------
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{notification}')
		BEGIN
			UPDATE tp
			SET tp.Content_en = n.Content_en
				,tp.Content_ch = n.Content_ch
				,tp.Content_cs = n.Content_cs
			FROM #tmpTemplateDetl AS tp
				INNER JOIN Notification AS n WITH (NOLOCK) ON tp.Msg_NotiID = n.NotificationID
			WHERE tp.RequiredParam = '{notification}'
		END
	
		/*
			----------{Settlement log}----------
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam IN ('{cal_time}','{recal_time}'))
		BEGIN
			/*
				Build result name
			*/
			--step #1 - get Resource_en / Resource_ch / Resource_cs
			INSERT INTO #tmpBuildResult (
				SettlementLogID
				,ResourceID
				,OtherInfo
				,G
				,X
				,Y
				,ResultName_en
				,ResultName_ch
				,ResultName_cs
			)
			SELECT DISTINCT ex.SettlementLogID
				,ex.ResourceID
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.OtherInfo ELSE wrg.OtherInfo END AS OtherInfo
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.G ELSE wrg.G END AS G
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.X ELSE wrg.X END AS X
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.Y ELSE wrg.Y END AS Y
				,rf.RefValueEN AS ResultName_en
				,rf.RefValueCH AS ResultName_ch
				,rf.RefValueCS AS ResultName_cs
			FROM #tmpExtraInfo AS ex
				LEFT JOIN #tmpParsedResult AS atl ON ex.SettlementLogID = atl.SettlementLogID AND ex.ResourceID = atl.ResourceID AND atl.AmendInfo = 'ActualResult'
				LEFT JOIN #tmpParsedResult AS wrg ON ex.SettlementLogID = wrg.SettlementLogID AND ex.ResourceID = wrg.ResourceID AND wrg.AmendInfo = 'WrongResult'
				INNER JOIN #tmpRemotingRef AS rf ON ex.SettlementLogID = rf.SettlementLogID AND rf.RefId2 = ISNULL(atl.RefBettypeID, wrg.RefBettypeID)
			WHERE ex.ResourceID = ISNULL(atl.ResourceID, wrg.ResourceID)
				AND rf.GroupName = 'RefResource'
				AND rf.RefId1 = 'ResourceCricket'
			
			--step #2 - Replace X / Y
			UPDATE #tmpBuildResult
			SET ResultName_en = REPLACE(ResultName_en,'@X',X)
				,ResultName_ch = REPLACE(ResultName_ch,'@X',X)
				,ResultName_cs = REPLACE(ResultName_cs,'@X',X)
			WHERE ISNULL(CHARINDEX('@X',ResultName_en),0) > 0
				OR ISNULL(CHARINDEX('@X',ResultName_ch),0) > 0
				OR ISNULL(CHARINDEX('@X',ResultName_cs),0) > 0
			
			UPDATE #tmpBuildResult
			SET ResultName_en = REPLACE(ResultName_en,'@Y',Y)
				,ResultName_ch = REPLACE(ResultName_ch,'@Y',Y)
				,ResultName_cs = REPLACE(ResultName_cs,'@Y',Y)
			WHERE ISNULL(CHARINDEX('@Y',ResultName_en),0) > 0
				OR ISNULL(CHARINDEX('@Y',ResultName_ch),0) > 0
				OR ISNULL(CHARINDEX('@Y',ResultName_cs),0) > 0
			
			--step #2 - 2.1 Replace G / M for GameSession IN (1,8) - match 2 inning
			;WITH CTE_G_Inns AS (
				SELECT rs.SettlementLogID
					,rs.ResourceID
					,'G' + rs.G AS rG --Handle case 1 inning only later
				FROM #tmpBuildResult AS rs
					INNER JOIN #tmpExtraInfo AS rh ON rs.SettlementLogID = rh.SettlementLogID AND rs.ResourceID = rh.ResourceID AND rh.GameSession IN (1,8)
				WHERE ISNULL(CHARINDEX('@G',rs.ResultName_en),0) > 0
					OR ISNULL(CHARINDEX('@G',rs.ResultName_ch),0) > 0
					OR ISNULL(CHARINDEX('@G',rs.ResultName_cs),0) > 0
			)
			UPDATE af
			SET ResultName_en = REPLACE(rs.ResultName_en,'@G',rf.RefValueEN)
				,ResultName_ch = REPLACE(rs.ResultName_ch,'@G',rf.RefValueCH)
				,ResultName_cs = REPLACE(rs.ResultName_cs,'@G',rf.RefValueCS)
			FROM #tmpBuildResult AS rs
				INNER JOIN CTE_G_Inns AS inn ON rs.SettlementLogID = inn.SettlementLogID AND rs.ResourceID = inn.ResourceID
				LEFT JOIN #tmpRemotingRef AS rf ON rs.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResourceCricket' AND rf.RefId2 = inn.rG
			
			;WITH CTE_M_Inns AS (
				SELECT rs.SettlementLogID
					,rs.ResourceID
					,'M' + rs.G AS rM --Handle case 1 inning only later
				FROM #tmpBuildResult AS rs
					INNER JOIN #tmpExtraInfo AS rh ON rs.SettlementLogID = rh.SettlementLogID AND rs.ResourceID = rh.ResourceID AND rh.GameSession IN (1,8)
				WHERE ISNULL(CHARINDEX('@M',rs.ResultName_en),0) > 0
					OR ISNULL(CHARINDEX('@M',rs.ResultName_ch),0) > 0
					OR ISNULL(CHARINDEX('@M',rs.ResultName_cs),0) > 0
			)
			UPDATE rs
			SET ResultName_en = REPLACE(rs.ResultName_en,'@M',ISNULL(rf.RefValueEN,''))
				,ResultName_ch = REPLACE(rs.ResultName_ch,'@M',ISNULL(rf.RefValueCH,''))
				,ResultName_cs = REPLACE(rs.ResultName_cs,'@M',ISNULL(rf.RefValueCS,''))
			FROM #tmpBuildResult AS rs
				INNER JOIN CTE_M_Inns AS inn ON rs.SettlementLogID = inn.SettlementLogID AND rs.ResourceID = inn.ResourceID
				LEFT JOIN #tmpRemotingRef AS rf ON rs.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResourceCricket' AND rf.RefId2 = inn.rM
			
			----step #2 - 2.2 Replace G / M for GameSession NOT IN (1,8) - match 1 inning only
			UPDATE #tmpBuildResult
			SET ResultName_en = REPLACE(REPLACE(ResultName_en,' @G ',' '),'@G','')
				,ResultName_ch = REPLACE(REPLACE(ResultName_ch,' @G ',' '),'@G','')
				,ResultName_cs = REPLACE(REPLACE(ResultName_cs,' @G ',' '),'@G','')
			
			UPDATE #tmpBuildResult
			SET ResultName_en = REPLACE(REPLACE(ResultName_en,' @M ',' '),'@M','')
				,ResultName_ch = REPLACE(REPLACE(ResultName_ch,' @M ',' '),'@M','')
				,ResultName_cs = REPLACE(REPLACE(ResultName_cs,' @M ',' '),'@M','')
			
			--step #4 - rule#1.If exists OtherInfo => put it after the Resource_en
			;WITH CTE_OtherInfo AS (
				SELECT rs.SettlementLogID
					,rs.ResourceID
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueEN),',') AS r_en
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueCH),',') AS r_ch
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueCS),',') AS r_cs
				FROM #tmpBuildResult AS rs
					CROSS APPLY STRING_SPLIT(rs.OtherInfo, ',') AS o
					INNER JOIN #tmpRemotingRef AS rf ON rs.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = o.value
				WHERE TRY_CONVERT(INT,o.value) IS NOT NULL
				GROUP BY rs.SettlementLogID
					,rs.ResourceID
			)
			UPDATE rs
			SET rs.ResultName_en = rs.ResultName_en + ' - ' + TRIM(o.r_en)
				,rs.ResultName_ch = rs.ResultName_ch + ' - ' + TRIM(o.r_ch)
				,rs.ResultName_cs = rs.ResultName_cs + ' - ' + TRIM(o.r_cs)
			FROM #tmpBuildResult AS rs
				INNER JOIN CTE_OtherInfo AS o ON rs.SettlementLogID = o.SettlementLogID AND rs.ResourceID = o.ResourceID
			
			/*
				Build ActualResult
			*/
			UPDATE #tmpBuildResult
			SET ActualResult_en = @Refund_en
				,ActualResult_ch = @Refund_ch
				,ActualResult_cs = @Refund_cs
			WHERE ActionType = 2 --CAL to Refund => WrongResult [have value] + ActualResult [blank]
			
			--2.If exists TeamIDs
			;WITH CTE_TeamID AS (
				SELECT atl.SettlementLogID
					,atl.ResourceID
					,rf.RefValueEN AS TeamName_en
					,rf.RefValueCH AS TeamName_ch
					,rf.RefValueCS AS TeamName_cs
				FROM #tmpParsedResult AS atl
					CROSS APPLY STRING_SPLIT(atl.TeamIDs, ',') AS t
					INNER JOIN #tmpRemotingRef AS rf ON atl.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = t.value
				WHERE atl.AmendInfo = 'ActualResult'
					AND TRY_CONVERT(INT,t.value) IS NOT NULL
			)
			UPDATE rs
			SET rs.ActualResult_en = t.TeamName_en
				,rs.ActualResult_ch = t.TeamName_ch
				,rs.ActualResult_cs = t.TeamName_cs
			FROM #tmpBuildResult AS rs
				INNER JOIN CTE_TeamID AS t ON rs.SettlementLogID = t.SettlementLogID AND rs.ResourceID = t.ResourceID
			WHERE rs.ActionType <> 2
					
			--3.If HomeValue is number
			UPDATE rs
			SET rs.ActualResult_en = atl.HomeValue
				,rs.ActualResult_ch = atl.HomeValue
				,rs.ActualResult_cs = atl.HomeValue
			FROM #tmpBuildResult AS rs
				INNER JOIN #tmpParsedResult AS atl ON rs.SettlementLogID = atl.SettlementLogID AND rs.ResourceID = t.ResourceID
			WHERE atl.AmendInfo = 'ActualResult'
				AND rs.ActionType <> 2
				AND rs.ActualResult_en IS NULL
				AND ISNUMERIC(REPLACE(ISNULL(atl.HomeValue,''),',','')) = 1
					
			--4.If HomeValue is NOT number
			UPDATE rs
			SET rs.ActualResult_en = rf.RefValueEN
				,rs.ActualResult_ch = rf.RefValueCH
				,rs.ActualResult_cs = rf.RefValueCS
			FROM #tmpBuildResult AS rs
				INNER JOIN #tmpParsedResult AS atl ON rs.SettlementLogID = atl.SettlementLogID AND rs.ResourceID = atl.ResourceID
				INNER JOIN #tmpRemotingRef AS rf ON rs.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResultSettlement' AND rf.RefId2 = atl.HomeValue
			WHERE atl.AmendInfo = 'ActualResult'
				AND rs.ActionType <> 2
				AND rs.ActualResult_en IS NULL
				AND ISNUMERIC(REPLACE(ISNULL(atl.HomeValue,''),',','')) = 0
					
			--5.the rest, value of HomeValue
			UPDATE rs
			SET rs.ActualResult_en = atl.HomeValue
				,rs.ActualResult_ch = atl.HomeValue
				,rs.ActualResult_cs = atl.HomeValue
			FROM #tmpBuildResult AS rs
				INNER JOIN #tmpParsedResult AS atl ON rs.SettlementLogID = atl.SettlementLogID AND rs.ResourceID = atl.ResourceID
			WHERE atl.AmendInfo = 'ActualResult'
				AND rs.ActionType <> 2
				AND rs.ActualResult_en IS NULL
			
			/*
				Build WrongResult
			*/
			UPDATE #tmpBuildResult
			SET WrongResult_en = @Refund_en
				,WrongResult_ch = @Refund_ch
				,WrongResult_cs = @Refund_cs
			WHERE ActionType = 3 --Refund to CAL => WrongResult [blank] + ActualResult [have value]
			
			--2.If exists TeamIDs
			;WITH CTE_TeamID AS (
				SELECT atl.SettlementLogID
					,atl.ResourceID
					,rf.RefValueEN AS TeamName_en
					,rf.RefValueCH AS TeamName_ch
					,rf.RefValueCS AS TeamName_cs
				FROM #tmpParsedResult AS atl
					CROSS APPLY STRING_SPLIT(atl.TeamIDs, ',') AS t
					INNER JOIN #tmpRemotingRef AS rf ON atl.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = t.value
				WHERE atl.AmendInfo = 'WrongResult'
					AND TRY_CONVERT(INT,t.value) IS NOT NULL
			)
			UPDATE rs
			SET rs.WrongResult_en = t.TeamName_en
				,rs.WrongResult_ch = t.TeamName_ch
				,rs.WrongResult_cs = t.TeamName_cs
			FROM #tmpBuildResult AS rs
				INNER JOIN CTE_TeamID AS t ON rs.SettlementLogID = t.SettlementLogID AND rs.ResourceID = t.ResourceID
			WHERE rs.ActionType <> 3
					
			--3.If HomeValue is number
			UPDATE rs
			SET rs.WrongResult_en = atl.HomeValue
				,rs.WrongResult_ch = atl.HomeValue
				,rs.WrongResult_cs = atl.HomeValue
			FROM #tmpBuildResult AS rs
				INNER JOIN #tmpParsedResult AS atl ON rs.SettlementLogID = atl.SettlementLogID AND rs.ResourceID = t.ResourceID
			WHERE atl.AmendInfo = 'WrongResult'
				AND rs.ActionType <> 3
				AND rs.WrongResult_en IS NULL
				AND ISNUMERIC(REPLACE(ISNULL(atl.HomeValue,''),',','')) = 1
					
			--4.If HomeValue is NOT number
			UPDATE rs
			SET rs.WrongResult_en = rf.RefValueEN
				,rs.WrongResult_ch = rf.RefValueCH
				,rs.WrongResult_cs = rf.RefValueCS
			FROM #tmpBuildResult AS rs
				INNER JOIN #tmpParsedResult AS atl ON rs.SettlementLogID = atl.SettlementLogID AND rs.ResourceID = atl.ResourceID
				INNER JOIN #tmpRemotingRef AS rf ON rs.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResultSettlement' AND rf.RefId2 = atl.HomeValue
			WHERE atl.AmendInfo = 'WrongResult'
				AND rs.ActionType <> 3
				AND rs.WrongResult_en IS NULL
				AND ISNUMERIC(REPLACE(ISNULL(atl.HomeValue,''),',','')) = 0
					
			--5.the rest, value of HomeValue
			UPDATE rs
			SET rs.WrongResult_en = atl.HomeValue
				,rs.WrongResult_ch = atl.HomeValue
				,rs.WrongResult_cs = atl.HomeValue
			FROM #tmpBuildResult AS rs
				INNER JOIN #tmpParsedResult AS atl ON rs.SettlementLogID = atl.SettlementLogID AND rs.ResourceID = atl.ResourceID
			WHERE atl.AmendInfo = 'WrongResult'
				AND rs.ActionType <> 3
				AND rs.WrongResult_en IS NULL
			
			/*
				build final data for [Settlement Log]
				**LogDateTime = FORMAT(GETDATE(),'MMM dd, yyyy hh:mm:ss tt')
				
				----|---------------|---------------|---------------------------|---------------------------------------------------|-----------------------------------------------------------|
					|Msg_NotiID		|LogType		|LogDateTime				|ResultName_en										|ResultName_cs												|
				----|---------------|---------------|---------------------------|---------------------------------------------------|-----------------------------------------------------------|
					| 1				| Calculation	| Oct 26, 2023 02:11:37 PM	| Home Over 11 Runs OE; 0							| 主队第 11 轮准确跑位得分盘 OE; 0								|
					| 1				| Calculation	| Oct 26, 2023 03:05:13	PM	| Home Over 10 Runs; 1								| 主队第 10 轮准确跑位得分盘; 1									|
					| 1				| ReCalculation	| Oct 27, 2023 09:13:18 AM	| Home Over 11 Runs OE; 1 | Home Over 10 Runs; 2	| 主队第 11 轮准确跑位得分盘 OE; 1 | 主队第 10 轮准确跑位得分盘; 2	|
				----|---------------|---------------|---------------------------|---------------------------------------------------|-----------------------------------------------------------|
			*/
			;WITH CTE_ResultByNoti AS (
				SELECT ex.Msg_NotiID
					,ex.Calc
					,ex.ReCalc
					,r.ResultName_en
					,r.ResultName_ch
					,r.ResultName_cs
					,r.ActualResult_en
					,r.ActualResult_ch
					,r.ActualResult_cs
					,r.WrongResult_en
					,r.WrongResult_ch
					,r.WrongResult_cs
				FROM #tmpExtraInfo AS ex
					LEFT JOIN #tmpBuildResult AS r ON ex.SettlementLogID = r.SettlementLogID AND ex.ResourceID = r.ResourceID
			)
			,CTE_ReCalc_Raw AS (
				SELECT DISTINCT Msg_NotiID
					,ReCalc
					,ResultName_en + '; ' + ActualResult_en AS ResultName_en
					,ResultName_ch + '; ' + ActualResult_ch AS ResultName_ch
					,ResultName_cs + '; ' + ActualResult_cs AS ResultName_cs
				FROM CTE_ResultByNoti
			)
			,CTE_ReCalc AS (
				SELECT Msg_NotiID
					,ReCalc AS LogDateTime
					,'ReCalculation' AS LogType
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_en),' | ') AS ResultName_en
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_ch),' | ') AS ResultName_ch
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_cs),' | ') AS ResultName_cs
				FROM CTE_ReCalc_Raw
				GROUP BY Msg_NotiID
					,ReCalc
			)
			,CTE_Calc_Raw AS (
				SELECT DISTINCT Msg_NotiID
					,Calc
					,ResultName_en + '; ' + ActualResult_en AS ResultName_en
					,ResultName_ch + '; ' + ActualResult_ch AS ResultName_ch
					,ResultName_cs + '; ' + ActualResult_cs AS ResultName_cs
				FROM CTE_ResultByNoti
			)
			,CTE_Calc AS (
				SELECT Msg_NotiID
					,Calc AS LogDateTime
					,'Calculation' AS LogType
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_en),' | ') AS ResultName_en
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_ch),' | ') AS ResultName_ch
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_cs),' | ') AS ResultName_cs
				FROM CTE_Calc_Raw
				GROUP BY Msg_NotiID
					,Calc
			)
			INSERT INTO #tmpSettlLog (
				Msg_NotiID
				,LogType
				,LogDateTime
				,ResultName_en
				,ResultName_ch
				,ResultName_cs
			)
			SELECT Msg_NotiID
				,LogType
				,LogDateTime
				,ResultName_en
				,ResultName_ch
				,ResultName_cs
			FROM CTE_ReCalc
			
			UNION ALL
			
			SELECT Msg_NotiID
				,LogType
				,LogDateTime
				,ResultName_en
				,ResultName_ch
				,ResultName_cs
			FROM CTE_Calc
			
			/*
				Convert LogDateTime to String
				月	—>	Month
				日	—>	Day
				年	—>	Year
				下午	—>	PM
				早晨	->	AM --need confirm
			*/
			UPDATE #tmpSettlLog
			SET LogDateTime_en = FORMAT(LogDateTime,'MMM dd, yyyy hh:mm:ss tt')
				,LogDateTime_ch = REPLACE(REPLACE(FORMAT(LogDateTime,N'MM月 dd日, yyyy年 hh:mm:ss tt'),'PM',N'下午'),'AM',N'早晨')
				,LogDateTime_cs = REPLACE(REPLACE(FORMAT(LogDateTime,N'MM月 dd日, yyyy年 hh:mm:ss tt'),'PM',N'下午'),'AM',N'早晨')
			
			IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{cal_time}')
			BEGIN
				;WITH CTE_Calc AS (
					SELECT Msg_NotiID
						,STRING_AGG(CONVERT(NVARCHAR(MAX),('Calculate Time: ' + LogDateTime_en + ' [' + ResultName_en + ']')),'<br/>') WITHIN GROUP (ORDER BY LogDateTime) AS CalEN --<br/>: new line HTML format
						,STRING_AGG(CONVERT(NVARCHAR(MAX),(N'结算时间: ' + LogDateTime_ch + ' [' + ResultName_ch + ']')),'<br/>') WITHIN GROUP (ORDER BY LogDateTime) AS CalCH
						,STRING_AGG(CONVERT(NVARCHAR(MAX),(N'结算时间: ' + LogDateTime_cs + ' [' + ResultName_cs + ']')),'<br/>') WITHIN GROUP (ORDER BY LogDateTime) AS CalCS
					FROM #tmpSettlLog
					WHERE LogType = 'Calculation'
					GROUP BY Msg_NotiID
				)
				UPDATE tp
				SET tp.Content_en = c.CalEN
					,tp.Content_ch = c.CalCH
					,tp.Content_cs = c.CalCS
				FROM #tmpTemplateDetl AS tp
					INNER JOIN CTE_Calc AS c ON tp.Msg_NotiID = c.Msg_NotiID
				WHERE tp.RequiredParam = '{cal_time}'
			END
			
			IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{recal_time}')
			BEGIN
				;WITH CTE_ReCalc AS (
					SELECT Msg_NotiID
						,STRING_AGG(CONVERT(NVARCHAR(MAX),('Recalculate Time: ' + LogDateTime_en + ' [' + ResultName_en + ']')),'<br/>') WITHIN GROUP (ORDER BY LogDateTime) AS ReCalEN --<br/>: new line HTML format
						,STRING_AGG(CONVERT(NVARCHAR(MAX),(N'重新结算时间: ' + LogDateTime_ch + ' [' + ResultName_ch + ']')),'<br/>') WITHIN GROUP (ORDER BY LogDateTime) AS ReCalCH
						,STRING_AGG(CONVERT(NVARCHAR(MAX),(N'重新结算时间: ' + LogDateTime_cs + ' [' + ResultName_cs + ']')),'<br/>') WITHIN GROUP (ORDER BY LogDateTime) AS ReCalCS
					FROM #tmpSettlLog
					WHERE LogType = 'ReCalculation'
					GROUP BY Msg_NotiID
				)
				UPDATE tp
				SET tp.Content_en = rc.ReCalEN
					,tp.Content_ch = rc.ReCalCH
					,tp.Content_cs = rc.ReCalCS
				FROM #tmpTemplateDetl AS tp
					INNER JOIN CTE_ReCalc AS rc ON tp.Msg_NotiID = rc.Msg_NotiID
				WHERE tp.RequiredParam = '{recal_time}'
			END
		END
	
		/*
			Build LAP message [Content]
		*/
		SET @iLoop = 1
		WHILE EXISTS(SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParamID = @iLoop)
		BEGIN
			--Start to replace RequiredParams
			UPDATE lap
			SET lap.Content_en = REPLACE(lap.Content_en,tp.RequiredParam,tp.Content_en)
				,lap.Content_ch = REPLACE(lap.Content_ch,tp.RequiredParam,tp.Content_ch)
				,lap.Content_cs = REPLACE(lap.Content_cs,tp.RequiredParam,tp.Content_cs)
			FROM #tmpNoti AS lap
				INNER JOIN #tmpTemplateDetl AS tp ON lap.Msg_NotiID = tp.Msg_NotiID
			WHERE tp.RequiredParamID = @iLoop
			
			SET @iLoop = @iLoop + 1
		END
	
		/*
			Build LAP message [Subject]
		*/
		;WITH CTE_Subject AS (
			SELECT lap.Msg_NotiID
				,(CASE WHEN lap.Content_en IS NOT NULL THEN N'Result Amended ' + CONVERT(NVARCHAR, ex.EventDate, 103) END) AS Subject_en --(DD/MM/YYYY)
				,(CASE WHEN lap.Content_ch IS NOT NULL THEN N'赛果更正 ' + CONVERT(NVARCHAR, ex.EventDate, 103) END) AS Subject_ch
				,(CASE WHEN lap.Content_cs IS NOT NULL THEN N'赛果更正 ' + CONVERT(NVARCHAR, ex.EventDate, 103) END) AS Subject_cs
			FROM #tmpNoti AS lap
				INNER JOIN NotificationExtra AS ex WITH (NOLOCK) ON lap.Msg_NotiID = ex.NotificationID
		)
		,CTE_SubjectJSON AS (
			SELECT Msg_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT Subject_en
						,Subject_ch
						,Subject_cs
					FROM CTE_Subject AS t
					WHERE t.Msg_NotiID = s.Msg_NotiID
					FOR JSON PATH)
				) AS Subject
			FROM CTE_Subject AS s
		)
		UPDATE lap
		SET lap.Subject = j.Subject
		FROM #tmpNoti AS lap
			INNER JOIN CTE_SubjectJSON AS j ON lap.Msg_NotiID = j.Msg_NotiID
		
		-----------------verify before insert Notification----------------
		;WITH CTE_Error AS (
			SELECT s.Msg_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpTemplateDetl AS t
					WHERE t.Msg_NotiID = s.Msg_NotiID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpTemplateDetl AS s
			GROUP BY s.Msg_NotiID
		)
		,CTE_SettlLog AS (
			SELECT s.Msg_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpSettlLog AS t
					WHERE t.Msg_NotiID = s.Msg_NotiID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpSettlLog AS s
			GROUP BY s.Msg_NotiID
		)
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT n.Msg_NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Msg_NotiID - FAILED at [Build NotificationID LAP] - '
					+ 'Content_en = (' + ISNULL(n.Content_en,'NULL') + ')'
					+ ', Content_ch = (' + ISNULL(n.Content_ch,'NULL') + ')'
					+ ', Content_cs = (' + ISNULL(n.Content_cs,'NULL') + ')'
					+ ', Subject = ' + ISNULL(n.Subject,'NULL') + ')'
					+ ', #tmpTemplateDetl = (' + ISNULL(e.LTxt,'NULL') + ')'
					+ ', #tmpSettlLog = (' + ISNULL(se.LTxt,'NULL') + ')'
		FROM #tmpNoti AS n
			LEFT JOIN CTE_Error AS e ON n.Msg_NotiID = e.Msg_NotiID
			LEFT JOIN CTE_SettlLog AS se ON n.Msg_NotiID = se.Msg_NotiID
		WHERE n.Content_en IS NULL
			OR n.Content_ch IS NULL
			OR n.Content_cs IS NULL
			OR n.Subject IS NULL
		ORDER BY n.Msg_NotiID
		
		--delete invalid Msg_NotiID
		DELETE FROM #tmpNoti
		WHERE Content_en IS NULL
			OR Content_ch IS NULL
			OR Content_cs IS NULL
			OR Subject IS NULL
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while preparing Param for LAP message Template - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		
		;WITH CTE_NotiE AS (
			SELECT s.Msg_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpNoti AS t
					WHERE t.Msg_NotiID = s.Msg_NotiID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpNoti AS s
			GROUP BY s.Msg_NotiID
		)
		,CTE_TempE AS (
			SELECT s.Msg_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpTemplateDetl AS t
					WHERE t.Msg_NotiID = s.Msg_NotiID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpTemplateDetl AS s
			GROUP BY s.Msg_NotiID
		)
		,CTE_SettlLog AS (
			SELECT s.Msg_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpSettlLog AS t
					WHERE t.Msg_NotiID = s.Msg_NotiID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpSettlLog AS s
			GROUP BY s.Msg_NotiID
		)
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT DISTINCT Msg_NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Msg_NotiID - FAILED while preparing Param for LAP message Template - '
					+ '#tmpNoti = (' + ISNULL(ne.LTxt,'NULL') + ')'
					+ ', #tmpTemplateDetl = (' + ISNULL(te.LTxt,'NULL') + ')'
					+ ', #tmpSettlLog = (' + ISNULL(se.LTxt,'NULL') + ')'
					+ ', ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		FROM #tmpNoti AS n
			LEFT JOIN CTE_NotiE AS ne ON n.Msg_NotiID = ne.Msg_NotiID
			LEFT JOIN CTE_TempE AS te ON n.Msg_NotiID = te.Msg_NotiID
			LEFT JOIN CTE_SettlLog AS se ON n.Msg_NotiID = se.Msg_NotiID
	END CATCH
	
	/*
		#3 - Start to Insert Notification LAP
	*/
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpNoti)
	BEGIN TRY
		BEGIN TRANSACTION
		--insert Notification (foreach row) to get [IDENTITY NotificationID] + [InternalID]
		SELECT @iLoop = MIN(Msg_NotiID)
		FROM #tmpNoti
		
		WHILE EXISTS(SELECT 1 FROM #tmpNoti WHERE Msg_NotiID = @iLoop)
		BEGIN
			INSERT INTO Notification (
				StatusID
				,NotificationType
				,Subject
				,Content_en
				,Content_ch
				,Content_cs
			)
			OUTPUT INSERTED.NotificationID
				,@iLoop
			INTO #tmpInsertedNoti (
				Lap_NotiID
				,Msg_NotiID
			) --Get Inserted
			SELECT @StsGenerating --need to verify after [DONE] insert realted tables
				,2 AS NotificationType --Result Amendment to LAP
				,n.Subject
				,n.Content_en
				,n.Content_ch
				,n.Content_cs
			FROM #tmpNoti AS n
			WHERE n.Msg_NotiID = @iLoop
			
			--increase for loop
			SET @iLoop = (SELECT MIN(Msg_NotiID) FROM #tmpNoti WHERE Msg_NotiID > @iLoop)
		END
		
		--write log
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT i.Lap_NotiID
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Lap_NotiID - Inserted new Notification LAP with StatusID = ' + CONVERT(VARCHAR,n.StatusID)
		FROM #tmpInsertedNoti AS i
			INNER JOIN Notification AS n WITH (NOLOCK) ON n.NotificationID = i.Lap_NotiID
		ORDER BY i.Lap_NotiID
		
		/*
			Insert NotificationTarget
				TargetID: AgentID for LAP
		*/
		INSERT INTO #tmpNotiTarget WITH (TABLOCK)(
			Lap_NotiID
			,TargetID
			,TargetSite
			,CustID
			,TransID
		)
		SELECT DISTINCT i.Lap_NotiID
			,ntAgent.TargetID --Agent
			,ntAgent.TargetSite
			,ntCust.TargetID AS CustID
			,t.TransID
		FROM #tmpInsertedNoti AS i
			INNER JOIN NotificationTarget AS ntCust WITH (NOLOCK) ON i.Msg_NotiID = ntCust.NotificationID
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON ntCust.TargetID = c.CustID AND c.roleid = 1 --cust
			INNER JOIN NotificationTarget AS ntAgent WITH (NOLOCK) ON i.Msg_NotiID = ntAgent.NotificationID AND ntCust.TargetSite = ntAgent.TargetSite AND ntAgent.TargetID = c.recommend --agent
			INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON ntCust.TargetSite = s.site AND s.isDeposit = 1 --deposit
			CROSS APPLY OPENJSON(ntCust.ExtraInfo) WITH (
				TransID BIGINT '$.TransID'
			) AS t--OPENJSON case-sensitive
		
		CREATE CLUSTERED INDEX CIX_tmpNotiTarget ON #tmpNotiTarget (Lap_NotiID, TargetID)
		
		;WITH CTE_TransIDByCust AS (
			SELECT Lap_NotiID
				,TargetID
				,TargetSite
				,CustID
				,STRING_AGG(CONVERT(VARCHAR(MAX), TransID), ',') WITHIN GROUP (ORDER BY TransID) AS TransIDs
			FROM #tmpNotiTarget
			GROUP BY Lap_NotiID
				,TargetID
				,TargetSite
				,CustID
		)
		INSERT INTO NotificationTarget (
			NotificationID
			,StatusID
			,TargetID
			,TargetSite
			,ExtraInfo
		)
		SELECT s.Lap_NotiID
			,@StsNew AS StatusID ----NO need to verify after [DONE] insert
			,s.TargetID
			,s.TargetSite
			,CONVERT(NVARCHAR(MAX), (
					SELECT DISTINCT t.CustID
						,t.TransIDs
					FROM CTE_TransIDByCust AS t
					WHERE t.Lap_NotiID = s.Lap_NotiID
						AND t.TargetID = s.TargetID
						AND t.TargetSite = s.TargetSite
					ORDER BY t.CustID
					FOR JSON AUTO
					)) AS ExtraInfo
		FROM CTE_TransIDByCust AS s
		GROUP BY s.Lap_NotiID
			,s.TargetID
			,s.TargetSite
			
		/*
			Insert NotiMapping
		*/
		INSERT INTO NotiMapping (
			SettlementLogID
			,NotificationID
		)
		SELECT DISTINCT nm.SettlementLogID
			,i.Lap_NotiID
		FROM #tmpInsertedNoti AS i --from Inserted Lap_NotiID --> retrive Msg_NotiID -> retrive NotiMapping => SettlementLogID
			INNER JOIN NotificationTarget AS lnt WITH (NOLOCK) ON i.Lap_NotiID = lnt.NotificationID --make sure exists in NotificationTarget
			INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON i.Msg_NotiID = nm.NotificationID
		
		/*
			Insert NotificationExtra
		*/
		INSERT INTO NotificationExtra (
			NotificationID
			,EventDate
			,ExtraInfo
		)
		SELECT DISTINCT i.Lap_NotiID
			,ex.EventDate
			,CONVERT(NVARCHAR(MAX),(
				SELECT DISTINCT tp.Msg_NotiID AS MsgNotiID
					,REPLACE(rcal.Content_en,'<br/>','{new_line}') AS ReCalEN --remove [new line] tag of HTML format
					,REPLACE(rcal.Content_ch,'<br/>','{new_line}') AS ReCalCH
					,REPLACE(rcal.Content_cs,'<br/>','{new_line}') AS ReCalCS
					,REPLACE(cal.Content_en,'<br/>','{new_line}') AS CalEN
					,REPLACE(cal.Content_ch,'<br/>','{new_line}') AS CalCH
					,REPLACE(cal.Content_cs,'<br/>','{new_line}') AS CalCS
				FROM #tmpTemplateDetl AS tp
					LEFT JOIN #tmpTemplateDetl AS rcal ON tp.Msg_NotiID = rcal.Msg_NotiID AND rcal.RequiredParam = '{recal_time}'
					LEFT JOIN #tmpTemplateDetl AS cal ON tp.Msg_NotiID = cal.Msg_NotiID AND cal.RequiredParam = '{cal_time}'
				WHERE tp.Msg_NotiID = i.Msg_NotiID
				FOR JSON PATH
			)) AS ExtraInfo
		FROM #tmpInsertedNoti AS i
			INNER JOIN NotificationTarget AS lnt WITH (NOLOCK) ON i.Lap_NotiID = lnt.NotificationID --make sure exists in NotificationTarget
			INNER JOIN NotificationExtra AS ex WITH (NOLOCK) ON i.Msg_NotiID = ex.NotificationID
		
		/*
			Start to final update Notification.StatusID
		*/
		
		-- Check after insert NotiMapping / Notification / NotificationTarget / NotificationExtra
			-- + Update Notification StatusID = @StsNew
		;WITH CTE_Valid AS (
			SELECT DISTINCT n.NotificationID
			FROM Notification AS n
				INNER JOIN NotificationTarget AS nt ON n.NotificationID = nt.NotificationID
				INNER JOIN NotiMapping AS nm ON nt.NotificationID = nm.NotificationID
				INNER JOIN NotificationExtra AS ne ON nm.NotificationID = ne.NotificationID
				INNER JOIN #tmpInsertedNoti AS i ON ne.NotificationID = i.Lap_NotiID
			WHERE n.StatusID = @StsGenerating
				AND n.NotificationType = 2 --notification for LAP
		)
		UPDATE n
		SET n.StatusID = @StsNew
		FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
			LEFT JOIN CTE_Valid AS v ON n.NotificationID = v.NotificationID
		
		--write log
		;WITH CTE_Error AS (
			SELECT DISTINCT i.Lap_NotiID
				,i.Msg_NotiID
			FROM #tmpInsertedNoti AS i
				INNER JOIN Notification AS n WITH (NOLOCK) ON i.Lap_NotiID = n.NotificationID
			WHERE n.StatusID <> @StsNew
		)
		,CTE_Target AS (
			SELECT DISTINCT e.Lap_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpNotiTarget AS t
					WHERE t.Lap_NotiID = e.Lap_NotiID
					FOR JSON PATH
				)) AS TLog
			FROM CTE_Error AS e
		)
		,CTE_Mapping AS (
			SELECT DISTINCT e.Lap_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM NotiMapping AS t WITH (NOLOCK)
					WHERE t.NotificationID = e.Msg_NotiID
					FOR JSON PATH
				)) AS TLog
			FROM CTE_Error AS e
		)
		,CTE_Noti AS (
			SELECT DISTINCT e.Lap_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpNoti AS t
					WHERE t.Msg_NotiID = e.Msg_NotiID
					FOR JSON PATH
				)) AS TLog
			FROM CTE_Error AS e
		)
		,CTE_TemplateDetl AS (
			SELECT DISTINCT e.Lap_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpTemplateDetl AS t
					WHERE t.Msg_NotiID = e.Msg_NotiID
					FOR JSON PATH
				)) AS TLog
			FROM CTE_Error AS e
		)
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT i.Lap_NotiID
			,@LogActionID
			,@LogUserID
			,CASE WHEN e.Lap_NotiID IS NULL THEN @InfLogPrefix + 'Lap_NotiID - Changed NotificationID LAP Status from [Generating] to [New]'
				ELSE @ErrLogPrefix + 'Lap_NotiID - FAILED while INSERT new Notification LAP - All Info as JSON: '
						+ 'Target = (' + ISNULL(t.TLog,'NULL') + ')'
						+ ', Mapping = (' + ISNULL(m.TLog,'NULL') + ')'
						+ ', Prepared Noti = (' + ISNULL(n.TLog,'NULL') + ')'
						+ ', TemplateDetl = (' + ISNULL(tp.TLog,'NULL') + ')'
				END
		FROM #tmpInsertedNoti AS i
			LEFT JOIN CTE_Error AS e ON i.Lap_NotiID = e.Lap_NotiID
			LEFT JOIN CTE_Target AS t ON i.Lap_NotiID = t.Lap_NotiID
			LEFT JOIN CTE_Mapping AS m ON i.Lap_NotiID = m.Lap_NotiID
			LEFT JOIN CTE_Noti AS n ON i.Lap_NotiID = n.Lap_NotiID
			LEFT JOIN CTE_TemplateDetl AS tp ON i.Lap_NotiID = tp.Lap_NotiID
		ORDER BY i.Lap_NotiID
		
		/*	the rest, deleted
				
			1.Keep Failed NotiID in #tmpInsertedNoti
			2.DEL Failed NotiID
		*/
		;WITH CTE_FailedNoti AS (
			SELECT DISTINCT i.Lap_NotiID
			FROM #tmpInsertedNoti AS i
				INNER JOIN Notification AS n WITH (NOLOCK) ON i.Lap_NotiID = n.NotificationID
			WHERE n.StatusID <> @StsNew
		)
		DELETE i
		FROM #tmpInsertedNoti AS i
		WHERE i.Lap_NotiID NOT IN (SELECT DISTINCT Lap_NotiID FROM CTE_FailedNoti) --delete valid NotificationID
		
		--DEL Failed NotiID - #tmpInsertedNoti keep Failed NotiID
			--Notification
			--NotificationTarget
			--NotiMapping
			--NotificationExtra
		DELETE FROM Notification
		WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpInsertedNoti)
		
		DELETE FROM NotificationTarget
		WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpInsertedNoti)
		
		DELETE FROM NotiMapping
		WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpInsertedNoti)
		
		DELETE FROM NotificationExtra
		WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpInsertedNoti)
		
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while INSERT new Notification LAP - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		-----------------------------------------------------------------------
		
		ROLLBACK TRANSACTION
		
		-----------------------------------------------------------------------
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'ROLLBACK INSERT new Notification LAP - Lap_NotiIDs (' + ISNULL((SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), Lap_NotiID), ',') FROM #tmpInsertedNoti),'NULL') + ')'
				+ ' - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		--------------------------
		IF EXISTS (SELECT 1 FROM #tmpInsertedNoti)
		BEGIN
			DELETE FROM Notification
			WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpInsertedNoti)
			
			DELETE FROM NotificationTarget
			WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpInsertedNoti)
			
			DELETE FROM NotiMapping
			WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpInsertedNoti)
			
			DELETE FROM NotificationExtra
			WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpInsertedNoti)
		END
	END CATCH
	
	DROP TABLE #tmpRemotingRef
	DROP TABLE #tmpExtraInfo
	DROP TABLE #tmpParsedResult
	DROP TABLE #tmpBuildResult
	DROP TABLE #tmpSettlLog
	DROP TABLE #tmpInsertedNoti
	DROP TABLE #tmpNoti
	DROP TABLE #tmpNotiTarget
	DROP TABLE #tmpTemplateDetl
END
