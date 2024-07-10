/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_GenNotificationLAP
	@Environment VARCHAR(20)
	,@JSRemotingRef NVARCHAR(MAX)
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
			If IncludeTestMatch = ON
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If IncludeTestMatch = OFF
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
		
		Input
			@JSRemotingRef NVARCHAR(MAX) = N'
				[
					[{"NotificationIDs":"1886,1893","GroupName":"EventInfo","RefId1":"SportType","RefId2":"50"}]
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
		,@ProcessID INT
		,@StsNew TINYINT
		,@StsGenerating TINYINT
		,@SettlIDs NVARCHAR(MAX)
		,@JSResource NVARCHAR(MAX)
		,@ErrLogPrefix NVARCHAR(150)
		,@InfLogPrefix NVARCHAR(150)
		,@LogMode VARCHAR(500)
		,@iLoop INT
		,@Refund_en NVARCHAR(20) = 'Refund'
		,@Refund_ch NVARCHAR(20) = N'退款'
		,@Refund_cs NVARCHAR(20) = N'退款'
		,@PRODIncludeTest BIT = 0
		,@IsTestFlag BIT
	
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
	
	SELECT @LogMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
	
	SELECT @PRODIncludeTest = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --IncludeTestMatch
	
	IF @Environment = 'LIVE'
	BEGIN
		SELECT @ProcessID = 9 --GenerateLAPNotifService
		SELECT @ErrLogPrefix = 'Error - [GenerateLAPNotifService - Gen] - '
		SELECT @InfLogPrefix = 'Info - [GenerateLAPNotifService - Gen] - '
	END
	ELSE
	BEGIN
		SELECT @ProcessID = 14 --UAT_GenerateLAPNotifService
		SELECT @ErrLogPrefix = 'Error - [UAT_GenerateLAPNotifService - Gen] - '
		SELECT @InfLogPrefix = 'Info - [UAT_GenerateLAPNotifService - Gen] - '
		
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
	-----------------------------------------------
	CREATE TABLE #tmpEventInfo (
		Msg_NotiID INT
		,IsTest BIT
		,MatchID INT
		,KOTime DATETIME
		,SportNameEN NVARCHAR(500)
		,SportNameCH NVARCHAR(500)
		,SportNameCS NVARCHAR(500)
		,HomeNameEN NVARCHAR(500)
		,HomeNameCH NVARCHAR(500)
		,HomeNameCS NVARCHAR(500)
		,AwayNameEN NVARCHAR(500)
		,AwayNameCH NVARCHAR(500)
		,AwayNameCS NVARCHAR(500)
		,NeutralEN NVARCHAR(10)
		,NeutralCH NVARCHAR(10)
		,NeutralCS NVARCHAR(10)
		,LeagueNameEN NVARCHAR(500)
		,LeagueNameCS NVARCHAR(500)
		,LeagueNameCH NVARCHAR(500)
	)

	CREATE TABLE #tmpExtraInfo (
		Msg_NotiID INT
		,SettlementLogID INT
		,ResourceID VARCHAR(50)
		,ReCalc DATETIME
		,Calc DATETIME
	)
	
	CREATE TABLE #tmpAffectedResult (
		Msg_NotiID INT
		,ResourceID VARCHAR(50)
		,ResultName_en NVARCHAR(4000)
		,ResultName_ch NVARCHAR(4000)
		,ResultName_cs NVARCHAR(4000)
		
		,ActualValue_en NVARCHAR(4000)
		,ActualValue_ch NVARCHAR(4000)
		,ActualValue_cs NVARCHAR(4000)
		
		,WrongValue_en NVARCHAR(4000)
		,WrongValue_ch NVARCHAR(4000)
		,WrongValue_cs NVARCHAR(4000)
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
		,MessageID INT NOT NULL
		,TemplateID SMALLINT NOT NULL
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
	
	CREATE TABLE #tmpFailedNoti (
		Lap_NotiID INT NOT NULL PRIMARY KEY
	)
	
	CREATE TABLE #tmpInputNoti (
		Msg_NotiID INT
		,SportType INT
		,TemplateID SMALLINT
	)
	
	--write log for LogMode = Debug
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Input @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')')
	/*
		#1 - Start to Parse inputed JSON
	*/
	BEGIN TRY
		INSERT INTO #tmpInputNoti (
			Msg_NotiID
			,SportType
		)
		SELECT DISTINCT TRY_CONVERT(INT,i.value) AS Msg_NotiID
			,SportType
		FROM OPENJSON(@JSRemotingRef) WITH (
				NotificationIDs VARCHAR(MAX) '$.NotificationIDs'
				,SportType SMALLINT '$.RefId2'
			)--OPENJSON case-sensitive
			CROSS APPLY STRING_SPLIT(NotificationIDs, ',') AS i
		
		/*
			***************************************************<<<!IMPORTANT HARDCODE>>>***************************************************
			TemplateID for Cricket
		*/
		UPDATE i
		SET i.TemplateID = (CASE WHEN i.SportType = 50 THEN 6 END) --currently, only have 1 message TemplateID for LAP Cricket
		FROM #tmpInputNoti AS i
		
		--DELETE invalid NotificationID
		DELETE i
		FROM #tmpInputNoti AS i
			LEFT JOIN Notification AS n WITH (NOLOCK) ON i.Msg_NotiID = n.NotificationID AND n.NotificationType = 1 --1: Result Amendment to Msg
			LEFT JOIN NotiMapping AS mn WITH (NOLOCK) ON i.Msg_NotiID = mn.NotificationID
			LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON mn.SettlementLogID = rh.SettlementLogID
		WHERE i.Msg_NotiID IS NULL
			OR n.NotificationID IS NULL
			OR i.TemplateID IS NULL
			OR rh.IsTest <> ISNULL(@IsTestFlag,rh.IsTest)
		
		CREATE UNIQUE CLUSTERED INDEX CIX_tmpInputNoti ON #tmpInputNoti (Msg_NotiID)
		
		;WITH CTE_Ext AS (
			SELECT i.Msg_NotiID
				,rh.SettlementLogID
				,TRY_CONVERT(XML, rh.ExtraInfo) AS ExtraInfoXML
			FROM #tmpInputNoti AS i
				INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON i.Msg_NotiID = nm.NotificationID
				INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
		)
		INSERT INTO #tmpExtraInfo (
			Msg_NotiID
			,SettlementLogID
			,ResourceID
			,ReCalc
			,Calc
		)
		SELECT DISTINCT c.Msg_NotiID
			,c.SettlementLogID
			,NULLIF(TRIM(rh.ex.value('@Id', 'VARCHAR(50)')), '') AS ResourceID
			,rh.ex.value('@ReCalc', 'DATETIME') AS ReCalc
			,rh.ex.value('@Calc', 'DATETIME') AS Calc
		FROM CTE_Ext AS c
			CROSS APPLY c.ExtraInfoXML.nodes('root/r') rh(ex)
		WHERE NULLIF(TRIM(rh.ex.value('@Id', 'VARCHAR(50)')), '') IS NOT NULL
		CREATE CLUSTERED INDEX CIX_tmpExtraInfo ON #tmpExtraInfo (Msg_NotiID, SettlementLogID)
		
		;WITH CTE_LAP AS (
			SELECT DISTINCT ex.Msg_NotiID
			FROM NotificationTarget AS ntc WITH (NOLOCK)
				INNER JOIN #tmpExtraInfo AS ex ON ntc.NotificationID = ex.Msg_NotiID
				INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON ntc.TargetSite = s.site AND s.isDeposit = 1 --deposit user
				OUTER APPLY OPENJSON(ntc.ExtraInfo) WITH (
					TransID BIGINT '$.TransID'
				) AS t--OPENJSON case-sensitive
			WHERE t.TransID IS NOT NULL
				AND ISJSON(ntc.ExtraInfo) = 1
		)
		INSERT INTO #tmpNoti (
			Msg_NotiID
			,MessageID
			,TemplateID
			,Content_en
			,Content_ch
			,Content_cs
		)
		SELECT DISTINCT ex.Msg_NotiID
			,n.RefID AS MessageID
			,tp.TemplateID
			,tp.Content_en
			,tp.Content_ch
			,tp.Content_cs
		FROM #tmpExtraInfo AS ex
			INNER JOIN CTE_LAP AS l ON ex.Msg_NotiID = l.Msg_NotiID
			INNER JOIN Notification AS n WITH (NOLOCK) ON ex.Msg_NotiID = n.NotificationID
			INNER JOIN #tmpInputNoti AS i WITH (NOLOCK) ON ex.Msg_NotiID = i.Msg_NotiID
			INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON i.TemplateID = tp.TemplateID --HARDCODE Above - Cricket Result Amendment - Notification for LAP
		WHERE n.NotificationType = 1 --Result Amendment to Msg
		
		CREATE UNIQUE CLUSTERED INDEX CIX_tmpNoti ON #tmpNoti (Msg_NotiID)
		
		INSERT INTO #tmpEventInfo (
			Msg_NotiID
			,MatchID
			,KOTime
			,IsTest
			
			,SportNameEN
			,SportNameCH
			,SportNameCS
			
			,HomeNameEN
			,HomeNameCH
			,HomeNameCS
			
			,AwayNameEN
			,AwayNameCH
			,AwayNameCS
			
			,NeutralEN
			,NeutralCH
			,NeutralCS
			
			,LeagueNameEN
			,LeagueNameCS
			,LeagueNameCH
		)
		SELECT DISTINCT n.Msg_NotiID
			,m.MatchID
			,m.KOTime
			,m.IsTest
			
			,m.SportNameEN
			,m.SportNameCH
			,m.SportNameCS
			
			,m.HomeNameEN
			,m.HomeNameCH
			,m.HomeNameCS
			
			,m.AwayNameEN
			,m.AwayNameCH
			,m.AwayNameCS
			
			,m.NeutralEN
			,m.NeutralCH
			,m.NeutralCS
			
			,m.LeagueNameEN
			,m.LeagueNameCS
			,m.LeagueNameCH
		FROM #tmpNoti AS n
			INNER JOIN NotificationExtra AS ex WITH (NOLOCK) ON n.Msg_NotiID = ex.NotificationID
			OUTER APPLY OPENJSON(ex.ExtraInfo) WITH (
					HomeNameEN NVARCHAR(500) '$.HomeNameEN'
					,HomeNameCH NVARCHAR(500) '$.HomeNameCH'
					,HomeNameCS NVARCHAR(500) '$.HomeNameCS'
					,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
					,AwayNameCH NVARCHAR(500) '$.AwayNameCH'
					,AwayNameCS NVARCHAR(500) '$.AwayNameCS'
					,NeutralEN NVARCHAR(10) '$.NeutralEN'
					,NeutralCH NVARCHAR(10) '$.NeutralCH'
					,NeutralCS NVARCHAR(10) '$.NeutralCS'
					,LeagueNameEN NVARCHAR(500) '$.LeagueNameEN'
					,LeagueNameCS NVARCHAR(500) '$.LeagueNameCS'
					,LeagueNameCH NVARCHAR(500) '$.LeagueNameCH'
					,SportNameEN NVARCHAR(500) '$.SportNameEN'
					,SportNameCH NVARCHAR(500) '$.SportNameCH'
					,SportNameCS NVARCHAR(500) '$.SportNameCS'
					,IsTest BIT '$.IsTest'
					,MatchID INT '$.MatchID'
					,KOTime DATETIME '$.KOTime'
				) AS m--OPENJSON case-sensitive
		WHERE ISJSON(ex.ExtraInfo) = 1
		
		CREATE CLUSTERED INDEX CIX_tmpEventInfo ON #tmpEventInfo (Msg_NotiID)
		
		--write log--
		IF @LogMode = 'Debug'
			INSERT INTO UserLog (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,COMPRESS(@InfLogPrefix + 'Debug - Prepare data'
								+ ' - tmpNoti('
									+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
												SELECT *
												FROM #tmpNoti
												FOR JSON PATH
											))
										),'NO ROW') + ')'
								+ ' - tmpInputNoti('
									+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
												SELECT *
												FROM #tmpInputNoti
												FOR JSON PATH
											))
										),'NO ROW') + ')'
								+ ' - tmpExtraInfo('
									+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
												SELECT *
												FROM #tmpExtraInfo
												FOR JSON PATH
											))
										),'NO ROW') + ')')
		ELSE
			INSERT INTO UserLog (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,COMPRESS(@InfLogPrefix + 'Prepare data'
								+ ' - tmpNoti('
									+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
												SELECT Msg_NotiID
													,TemplateID
												FROM #tmpNoti
												FOR JSON PATH
											))
										),'NO ROW') + ')')
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while parsing inputed JSON to create NotificationID LAP - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
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
			UPDATE tp
			SET tp.Content_en = ev.HomeNameEN + ISNULL(' ' + ev.NeutralEN,'') + ' -vs- ' + ev.AwayNameEN
				,tp.Content_ch = ev.HomeNameCH + ISNULL(' ' + ev.NeutralCH,'') + ' -vs- ' + ev.AwayNameCH
				,tp.Content_cs = ev.HomeNameCS + ISNULL(' ' + ev.NeutralCS,'') + ' -vs- ' + ev.AwayNameCS
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpEventInfo AS ev ON tp.Msg_NotiID = ev.Msg_NotiID
			WHERE tp.RequiredParam = '{match_name}'
		END
	
		/*
			----------{league_name}----------
			The NotificationExtra handled for Non-Saba league name
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{league_name}')
		BEGIN
			UPDATE tp
			SET tp.Content_en = ev.LeagueNameEN
				,tp.Content_ch = ev.LeagueNameCS
				,tp.Content_cs = ev.LeagueNameCH
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpEventInfo AS ev ON tp.Msg_NotiID = ev.Msg_NotiID
			WHERE tp.RequiredParam = '{league_name}'
		END
	
		/*
			----------{KO_date}----------
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{KO_date}')
		BEGIN
			UPDATE tp
			SET tp.Content_en = CONVERT(VARCHAR(5),ev.KOTime,103)
				,tp.Content_ch = CONVERT(VARCHAR(5),ev.KOTime,103)
				,tp.Content_cs = CONVERT(VARCHAR(5),ev.KOTime,103)
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpEventInfo AS ev ON tp.Msg_NotiID = ev.Msg_NotiID
			WHERE tp.RequiredParam = '{KO_date}'
		END
	
		/*
			----------{notification}----------
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{notification}')
		BEGIN
			UPDATE tp
			SET tp.Content_en = REPLACE(n.Content_en,'@@','')
				,tp.Content_ch = REPLACE(n.Content_ch,'@@','')
				,tp.Content_cs = REPLACE(n.Content_cs,'@@','')
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
				Load AffectedResult from Msg Noti
			*/
			INSERT INTO #tmpAffectedResult (
				Msg_NotiID
				,ResourceID
				,ResultName_en
				,ResultName_ch
				,ResultName_cs
				,ActualValue_en
				,ActualValue_ch
				,ActualValue_cs
				,WrongValue_en
				,WrongValue_ch
				,WrongValue_cs
			)
			SELECT DISTINCT ex.Msg_NotiID
				,af.ResourceID
				,af.ResultName_en
				,af.ResultName_ch
				,af.ResultName_cs
				,af.ActualValue_en
				,af.ActualValue_ch
				,af.ActualValue_cs
				,af.WrongValue_en
				,af.WrongValue_ch
				,af.WrongValue_cs
			FROM #tmpExtraInfo AS ex
				INNER JOIN NotificationExtra AS ne WITH (NOLOCK) ON ex.Msg_NotiID = ne.NotificationID
				OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
						AffectedResult NVARCHAR(MAX) '$.AffectedResult' AS JSON
					) AS ext--OPENJSON case-sensitive
				OUTER APPLY OPENJSON(ext.AffectedResult) WITH (
						ResourceID VARCHAR(50) '$.ResourceID'
						,ResultName_en NVARCHAR(4000) '$.ResultName_en'
						,ResultName_ch NVARCHAR(4000) '$.ResultName_ch'
						,ResultName_cs NVARCHAR(4000) '$.ResultName_cs'
						,ActualValue_en NVARCHAR(4000) '$.ActualValue_en'
						,ActualValue_ch NVARCHAR(4000) '$.ActualValue_ch'
						,ActualValue_cs NVARCHAR(4000) '$.ActualValue_cs'
						,WrongValue_en NVARCHAR(4000) '$.WrongValue_en'
						,WrongValue_ch NVARCHAR(4000) '$.WrongValue_ch'
						,WrongValue_cs NVARCHAR(4000) '$.WrongValue_cs'
					) AS af--OPENJSON case-sensitive
			WHERE ISJSON(ne.ExtraInfo) = 1
				AND ISJSON(ext.AffectedResult) = 1
			
			/*
				build final data for [Settlement Log]
				**LogDateTime = FORMAT(GETDATE(),'MMM dd, yyyy hh:mm:ss tt')
				
				----|---------------|---------------|---------------------------|---------------------------------------------------|-----------------------------------------------------------|
					|Msg_NotiID		|LogType		|LogDateTime				|ResultName_en								        |****ResultName_cs****										|
				----|---------------|---------------|---------------------------|---------------------------------------------------|-----------------------------------------------------------|
					| 1				| Calculation	| Oct 26, 2023 02:11:37 PM	| Home Over 11 Runs OE; 0							| 主队第 11 轮准确跑位得分盘 OE; 0								|
					| 1				| Calculation	| Oct 26, 2023 03:05:13	PM	| Home Over 10 Runs; 1								| 主队第 10 轮准确跑位得分盘; 1									|
					| 1				| ReCalculation	| Oct 27, 2023 09:13:18 AM	| Home Over 11 Runs OE; 1 | Home Over 10 Runs; 2	| 主队第 11 轮准确跑位得分盘 OE; 1 | 主队第 10 轮准确跑位得分盘; 2	|
				----|---------------|---------------|---------------------------|---------------------------------------------------|-----------------------------------------------------------|
				
				****ResultName_cs****
					 = 主队第 11 轮准确跑位得分盘 OE; 1
						=> 	1.[主队第 11 轮准确跑位得分盘 OE] 	= #tmpAffectedResult.ResultName_cs
							2. [1] 							= #tmpAffectedResult.ActualValue_cs
			
			*/
			;WITH CTE_Calc_Raw AS (
				SELECT DISTINCT ex.Msg_NotiID
					,ex.Calc
					,r.ResultName_en + '; ' + r.WrongValue_en AS ResultName_en
					,r.ResultName_ch + '; ' + r.WrongValue_ch AS ResultName_ch
					,r.ResultName_cs + '; ' + r.WrongValue_cs AS ResultName_cs
				FROM #tmpExtraInfo AS ex
					LEFT JOIN #tmpAffectedResult AS r ON ex.Msg_NotiID = r.Msg_NotiID AND ex.ResourceID = r.ResourceID
			)
			,CTE_Calc AS (
				SELECT Msg_NotiID
					,Calc AS LogDateTime
					,'Calculation' AS LogType
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_en),' | ') WITHIN GROUP (ORDER BY ResultName_en) AS ResultName_en
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
			FROM CTE_Calc
			
			----------------------------------
			;WITH CTE_ReCalc_Raw AS (
				SELECT DISTINCT ex.Msg_NotiID
					,ex.ReCalc
					,ex.Calc
					,r.ResultName_en + '; ' + ActualValue_en AS ResultName_en
					,r.ResultName_ch + '; ' + ActualValue_ch AS ResultName_ch
					,r.ResultName_cs + '; ' + ActualValue_cs AS ResultName_cs
				FROM #tmpExtraInfo AS ex
					LEFT JOIN #tmpAffectedResult AS r ON ex.Msg_NotiID = r.Msg_NotiID AND ex.ResourceID = r.ResourceID
			)
			,CTE_ReCalc AS (
				SELECT Msg_NotiID
					,ReCalc AS LogDateTime
					,'ReCalculation' AS LogType
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_en),' | ') WITHIN GROUP (ORDER BY Calc, ResultName_en) AS ResultName_en --order recal result by calc time
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_ch),' | ') AS ResultName_ch
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ResultName_cs),' | ') AS ResultName_cs
				FROM CTE_ReCalc_Raw
				GROUP BY Msg_NotiID
					,ReCalc
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
			
			/*
				Convert LogDateTime to String
				月	—>	Month
				日	—>	Day
				年	—>	Year
				下午	—>	PM
				早晨	->	AM
			*/
			UPDATE #tmpSettlLog
			SET LogDateTime_en = FORMAT(LogDateTime,'MMM dd, yyyy hh:mm:ss tt')
				,LogDateTime_ch = REPLACE(REPLACE(FORMAT(LogDateTime,N'MM月 dd日, yyyy年 hh:mm:ss tt'),'PM',N'下午'),'AM',N'早晨')
				,LogDateTime_cs = REPLACE(REPLACE(FORMAT(LogDateTime,N'MM月 dd日, yyyy年 hh:mm:ss tt'),'PM',N'下午'),'AM',N'早晨')
			
			IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{cal_time}')
			BEGIN
				;WITH CTE_Calc AS (
					SELECT Msg_NotiID
						,STRING_AGG(CONVERT(NVARCHAR(MAX),('Calculation Time: ' + LogDateTime_en + ' [' + ResultName_en + ']')),'<br/>') WITHIN GROUP (ORDER BY LogDateTime) AS CalEN --<br/>: new line HTML format
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
						,STRING_AGG(CONVERT(NVARCHAR(MAX),('ReCalculation Time: ' + LogDateTime_en + ' [' + ResultName_en + ']')),'<br/>') WITHIN GROUP (ORDER BY LogDateTime) AS ReCalEN --<br/>: new line HTML format
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
			Build LAP message [Subject]
		*/
			UPDATE lap
			SET lap.Subject = N'赛果更正 | Result Amended (' + ISNULL(FORMAT(ev.KOTime, 'dd MMMM yyyy'),'NULL') + ')'
			FROM #tmpNoti AS lap
				INNER JOIN #tmpEventInfo AS ev ON lap.Msg_NotiID = ev.Msg_NotiID
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
		
		--write log
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Debug - Build message content'
							+ ' - tmpNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT Msg_NotiID
												,TemplateID
											FROM #tmpNoti
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - tmpTemplateDetl('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpTemplateDetl
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - tmpAffectedResult('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpAffectedResult
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - tmpSettlLog('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpSettlLog
											FOR JSON PATH
										))
									),'NO ROW') + ')')
		WHERE @LogMode = 'Debug'
		
		--delete invalid Msg_NotiID
		DELETE n
		FROM #tmpNoti AS n
			INNER JOIN NotiTemplate AS t WITH (NOLOCK) ON n.TemplateID = t.TemplateID
		WHERE (n.Content_en IS NULL AND t.Content_en IS NOT NULL)
			OR (n.Content_ch IS NULL AND t.Content_ch IS NOT NULL)
			OR (n.Content_cs IS NULL AND t.Content_cs IS NOT NULL)
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Build message content - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	--write log
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Build message completed'
						+ ' - tmpNoti('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpNoti
										FOR JSON PATH
									))
								),'NO ROW') + ')')
	/*
		#3 - Start to Insert Notification LAP
	*/
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpNoti)
	BEGIN TRY
		--insert Notification (foreach row) to get [IDENTITY NotificationID] + [InternalID]
		SELECT @iLoop = MIN(Msg_NotiID)
		FROM #tmpNoti
		
		WHILE EXISTS(SELECT 1 FROM #tmpNoti WHERE Msg_NotiID = @iLoop)
		BEGIN
			INSERT INTO Notification (
				RefID
				,StatusID
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
			SELECT n.MessageID
				,@StsGenerating --need to verify after [DONE] insert realted tables
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
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT Lap_NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Recent insertes LAP Notification (refer Msg Noti[' + ISNULL((CONVERT(VARCHAR,Msg_NotiID)),'NULL')+']) with status = [Generating]')
		FROM #tmpInsertedNoti AS i
		WHERE @LogMode = 'Debug'
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
		WHERE ISJSON(ntCust.ExtraInfo) = 1
		
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
					FOR JSON PATH
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
		;WITH CTE_SettlLog AS (
			SELECT s.Msg_NotiID
				,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT t.LogType
						,t.LogDateTime
						,t.LogDateTime_en
						,t.LogDateTime_ch
						,t.LogDateTime_cs
						,t.ResultName_en
						,t.ResultName_ch
						,t.ResultName_cs
					FROM #tmpSettlLog AS t
					WHERE t.Msg_NotiID = s.Msg_NotiID
					ORDER BY t.LogType
					FOR JSON PATH
				)) AS SettlLog
			FROM #tmpSettlLog AS s
			GROUP BY s.Msg_NotiID
		)
		INSERT INTO NotificationExtra (
			NotificationID
			,EventDate
			,ExtraInfo
		)
		SELECT DISTINCT i.Lap_NotiID
			,ex.EventDate
			,CONVERT(NVARCHAR(MAX),(
				SELECT DISTINCT m.Msg_NotiID AS MsgNotiID
					,m.MatchID
					,m.KOTime
					,m.IsTest
					,m.HomeNameEN
					,m.HomeNameCH
					,m.HomeNameCS
					,m.AwayNameEN
					,m.AwayNameCH
					,m.AwayNameCS
					,m.NeutralEN
					,m.NeutralCH
					,m.NeutralCS
					,m.SportNameEN
					,m.SportNameCH
					,m.SportNameCS
					---------TemplateName------
					,tp.TemplateName
					----------SettlLog------
					,sl.SettlLog
				FROM #tmpEventInfo AS m
					LEFT JOIN CTE_SettlLog AS sl ON m.Msg_NotiID = sl.Msg_NotiID
					LEFT JOIN #tmpInputNoti AS ii ON m.Msg_NotiID = ii.Msg_NotiID
					LEFT JOIN NotiTemplate AS tp WITH (NOLOCK) ON ii.TemplateID = tp.TemplateID
				WHERE m.Msg_NotiID = i.Msg_NotiID
				FOR JSON PATH
			)) AS ExtraInfo
		FROM #tmpInsertedNoti AS i
			INNER JOIN NotificationTarget AS lnt WITH (NOLOCK) ON i.Lap_NotiID = lnt.NotificationID --make sure exists in NotificationTarget
			INNER JOIN NotificationExtra AS ex WITH (NOLOCK) ON i.Msg_NotiID = ex.NotificationID
		
		--write log
		;WITH CTE_Log AS (
			SELECT i.Lap_NotiID
				,STRING_AGG(CONVERT(VARCHAR(MAX),nm.SettlementLogID),',') WITHIN GROUP (ORDER BY nm.SettlementLogID) AS SettlIDs
				,i.Msg_NotiID
			FROM #tmpInsertedNoti AS i
				INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON i.Lap_NotiID = nm.NotificationID
			GROUP BY i.Lap_NotiID
				,i.Msg_NotiID
		)
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT i.Lap_NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Created Notification Lap with Status = [' + ISNULL(st.Status,CONVERT(VARCHAR,n.StatusID)) + ']'
							+ ' - NotiMapping.SettlementLogID(' + ISNULL(l.SettlIDs,'NULL') + ')'
							+ ' - MsgNotiIDs(' + ISNULL(CONVERT(VARCHAR,l.Msg_NotiID),'NULL') + ')')
		FROM #tmpInsertedNoti AS i
			INNER JOIN Notification AS n WITH (NOLOCK) ON n.NotificationID = i.Lap_NotiID
			LEFT JOIN NotiStatus AS st WITH (NOLOCK) ON n.StatusID = st.StatusID
			LEFT JOIN CTE_Log AS l ON i.Lap_NotiID = l.Lap_NotiID
		ORDER BY i.Lap_NotiID
		
		/*
			Start to final update Notification.StatusID
		*/
		
		-- Check after insert NotiMapping / Notification / NotificationTarget / NotificationExtra
			-- + Update Notification StatusID = @StsNew
		;WITH CTE_Valid AS (
			SELECT DISTINCT i.Lap_NotiID
			FROM Notification AS n
				INNER JOIN NotificationTarget AS nt ON n.NotificationID = nt.NotificationID
				INNER JOIN NotiMapping AS nm ON nt.NotificationID = nm.NotificationID
				INNER JOIN NotificationExtra AS ne ON nm.NotificationID = ne.NotificationID
				INNER JOIN #tmpInsertedNoti AS i ON n.NotificationID = i.Lap_NotiID
			WHERE n.StatusID = @StsGenerating
				AND n.NotificationType = 2 --notification for LAP
		)
		UPDATE n
		SET n.StatusID = @StsNew
			-- ,n.LastModifiedTime = GETDATE() --no Need, just validate StatusID after inserted => leave it as is
		FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
			INNER JOIN CTE_Valid AS v ON n.NotificationID = v.Lap_NotiID
		
		--write log
		;WITH CTE_Log AS (
			SELECT Lap_NotiID AS RefID
				,Lap_NotiID
				,@InfLogPrefix + 'Changed NotificationID Status from [Generating] to [New]' AS LogTxt
			FROM #tmpInsertedNoti
			
			UNION ALL
			
			SELECT Msg_NotiID AS RefID
				,Lap_NotiID
				,@InfLogPrefix + 'SUCCESSFUL to generate LAP noti' AS LogTxt
			FROM #tmpInsertedNoti
		)
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT DISTINCT l.RefID
			,@LogActionID
			,@LogUserID
			,COMPRESS(l.LogTxt)
		FROM CTE_Log AS l
			INNER JOIN Notification AS n WITH (NOLOCK) ON n.NotificationID = l.Lap_NotiID
		WHERE n.StatusID = @StsNew
		ORDER BY l.RefID
		
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
		INSERT INTO #tmpFailedNoti (Lap_NotiID)
		SELECT DISTINCT Lap_NotiID
		FROM CTE_FailedNoti
		
		--DEL Failed NotiID
			--Notification
			--NotificationTarget
			--NotiMapping
			--NotificationExtra
		DELETE FROM Notification
		WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpFailedNoti)
		
		DELETE FROM NotificationTarget
		WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpFailedNoti)
		
		DELETE FROM NotiMapping
		WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpFailedNoti)
		
		DELETE FROM NotificationExtra
		WHERE NotificationID IN (SELECT Lap_NotiID FROM #tmpFailedNoti)
		
		--write log
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT Lap_NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'Deleted Notification after consistency checking')
		FROM #tmpFailedNoti
		ORDER BY Lap_NotiID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Insert new Lap Notification - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	--write log
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Inserted new Notification'
						+ ' - tmpInsertedNoti('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpInsertedNoti
										FOR JSON PATH
									))
								),'NO ROW') + ')'
						+ ' - tmpFailedNoti('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpFailedNoti
										FOR JSON PATH
									))
								),'NO ROW') + ')')
	
	/****************************************************************************
		Final mark Failed if @ErrCode <> 0
	****************************************************************************/
	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
		--DEL Failed NotiID
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
		
		--write log
		IF EXISTS (
			SELECT 1
			FROM #tmpInsertedNoti AS i
				LEFT JOIN #tmpFailedNoti AS f ON i.Lap_NotiID = f.Lap_NotiID
			WHERE f.Lap_NotiID IS NULL
		)
		BEGIN
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT i.Lap_NotiID
				,@LogActionID
				,@LogUserID
				,COMPRESS(@ErrLogPrefix + 'Recent [Notification] inserts have been removed - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
			FROM #tmpInsertedNoti AS i
				LEFT JOIN #tmpFailedNoti AS f ON i.Lap_NotiID = f.Lap_NotiID
			WHERE f.Lap_NotiID IS NULL --FailedNoti log above
			ORDER BY i.Lap_NotiID
		END
		ELSE
		BEGIN
			INSERT INTO UserLog (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,COMPRESS(@ErrLogPrefix + ISNULL(@ErrMsg,'NULL'))
		END
	END
	
	/****************************************************************************
	
		Change Process Status
		
	****************************************************************************/
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
	
	DROP TABLE #tmpExtraInfo
	DROP TABLE #tmpAffectedResult
	DROP TABLE #tmpSettlLog
	DROP TABLE #tmpInsertedNoti
	DROP TABLE #tmpNoti
	DROP TABLE #tmpNotiTarget
	DROP TABLE #tmpTemplateDetl
	DROP TABLE #tmpInputNoti
	DROP TABLE #tmpFailedNoti
	DROP TABLE #tmpEventInfo
END
