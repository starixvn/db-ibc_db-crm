/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_GenNotification
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
			SettlementResultHist
			NotiMapping
			Notification
			NotificationTarget
			NotificationExtra
		Steps
			#1.Load setting and create tmp Tables
			#2.Get ValidSettleIDs and write log input params
			#3.Prepare data to generate message
			#4.Start to Build message
			#5.Handle for duplicate Content_en and Prepare for insert
			#6.Start to insert data into
				- Insert Notification => Get NotificationID
				- Insert NotificationTarget refer to NotificationID
				- Insert NotiMapping refer to NotificationID / SettlementLogID
				- Insert NotificationExtra
			#7.Write final log before / after gen message
	Example:
		EXEC MessageNotification.dbo.MNC_ResultAmendment_GenNotification @JSSettlementLogIDs @JSRemotingRef
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@ProcessID INT
		,@LogActionID SMALLINT
		,@StsGenerated TINYINT
		,@StsGenerating TINYINT
		,@StsGenFailed TINYINT
		,@StsSending TINYINT
		,@StsNew TINYINT
		,@UATMode VARCHAR(5) = 'OFF'
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@ValidSettlementLogIDs VARCHAR(MAX)
		,@JSResource VARCHAR(MAX) = ''
		,@iLoop INT
		,@LogMode VARCHAR(500)
		,@SabaLeagueGroup VARCHAR(500) = '42,74,108,113,122,151,215'
		,@Saba_en NVARCHAR(10) = N'Saba'
		,@Saba_ch NVARCHAR(10) = N'沙巴'
		,@Saba_cs NVARCHAR(10) = N'沙巴'
		,@Neutral_en NVARCHAR(10) = N'(N)'
		,@Neutral_ch NVARCHAR(10) = N'(中)'
		,@Neutral_cs NVARCHAR(10) = N'(中)'
	
	/****************************************************************************
	
		#1.Load setting and create tmp Tables
		
	****************************************************************************/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @ProcessID = (
					CASE WHEN @Environment = 'LIVE' THEN 5 --Process_GenerateNoti
					ELSE 8 END --ProcessUAT_GenerateNoti
				)
				
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @StsGenerating = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Generating'
	
	SELECT @StsGenFailed = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Failed to Generate'
	
	SELECT @StsGenerated = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Successfully Generated'
	
	SELECT @StsSending = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sending'
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @LogMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
	
	SELECT @UATMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --UATMode
	
	SELECT @ErrLogPrefix = 'Error - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @InfLogPrefix = 'Info - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @Environment = ISNULL(@Environment,'UAT')
	
	/*
		Filter data by UATMode
			If UATMode = OFF
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If UATMode = ON
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
	*/
	IF @UATMode = 'OFF' AND @Environment = 'UAT' --no action (RETURN)
	BEGIN
		SELECT @ErrCode = 50001 --user-defined error code
			,@ErrMsg = 'NO Action for UATMode = OFF AND Environment = UAT'
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@InfLogPrefix + 'NO Action for UATMode = OFF AND Environment = UAT'
		
		RETURN
	END
	
	CREATE TABLE #tmpRemotingRef (
		SettlementLogID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
		,RefValueEN NVARCHAR(500)
		,RefValueCH NVARCHAR(500)
		,RefValueCS NVARCHAR(500)
	)
	CREATE CLUSTERED INDEX CIX_tmpRemotingRef ON #tmpRemotingRef (SettlementLogID)
	
	CREATE TABLE #tmpResultHist (
		SettlementLogID INT NOT NULL
		,StatusID TINYINT NOT NULL
		,NotiLogBef NVARCHAR(MAX) DEFAULT ''
		,SessionID VARCHAR(50)
		,SeqNo SMALLINT
		,MatchID INT
		,IsTest BIT
		,EventDate DATE
		,SportType INT
		,IsNeutral BIT
		,HomeID INT
		,AwayID INT
		,KOTime DATETIME
		,LeagueID INT
		,LeagueGroupID SMALLINT
		,GameSession TINYINT
		,ActionType TINYINT
		,ActualResultXML XML
		,WrongResultXML XML
		,AmendedCnt TINYINT DEFAULT 0
	)
	CREATE CLUSTERED INDEX CIX_tmpResultHist ON #tmpResultHist (SettlementLogID)
	/*
		Create Notification
			Group by 
				SessionID / ActionType => SettlementLogID
				/ IsSabaFilter
				/ user control group (OST or 777)
		
		1 SettlementLogID in #tmpResultHist
		can be 3 rows in #tmpNoti
			- IsSabaFilter = 0: Normal
			- IsSabaFilter = 1: Saba
				+ User Control Group (OST)
				+ User Control Group (777)
	*/
	CREATE TABLE #tmpNoti (
		SettlementLogID INT NOT NULL
		,IsSabaFilter BIT NOT NULL --0: Normal / 1: Saba
		,ControlGrp TINYINT NOT NULL --0: OST / 1: 777
		,TemplateID INT NOT NULL
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNoti ON #tmpNoti (SettlementLogID, IsSabaFilter, ControlGrp)
	
	/*
		1 NotificationID (SettlementLogID / IsSabaFilter / ControlGrp)
		have at least 4 rows in NotificationTarget for (CustID / recommend / mrecommend / srecommend)
	*/
	CREATE TABLE #tmpNotiTarget (
		SettlementLogID INT NOT NULL
		,IsSabaFilter BIT NOT NULL --0: Normal / 1: Saba
		,ControlGrp TINYINT NOT NULL --0: OST / 1: 777
		,TargetSite NVARCHAR(30)
		,CustID INT
		,AgentID INT
		,MasterID INT
		,SuperID INT
		,TransID BIGINT
	)
	CREATE CLUSTERED INDEX CIX_tmpNotiTarget ON #tmpNotiTarget (SettlementLogID, IsSabaFilter, ControlGrp)
	
	CREATE TABLE #tmpTemplateDetl (
		SettlementLogID INT NOT NULL
		,IsSabaFilter BIT NOT NULL --0: Normal / 1: Saba
		,ControlGrp TINYINT NOT NULL --0: OST / 1: 777
		,RequiredParamID INT
		,RequiredParam VARCHAR(50)
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	CREATE CLUSTERED INDEX CIX_tmpTemplateDetl ON #tmpTemplateDetl (SettlementLogID, IsSabaFilter)
	
	CREATE TABLE #tmpPrepareInsertNoti (
		GrpID INT
		,SettlementLogID INT
		,IsSabaFilter BIT
		,ControlGrp TINYINT
	)
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiInsList ON #tmpPrepareInsertNoti (SettlementLogID, IsSabaFilter, ControlGrp)
	
	CREATE TABLE #tmpInsertedNoti (
		NotificationID INT NOT NULL
		,GrpID INT
		,SuccessStatusID TINYINT --based on SystemSetting.VName = 'IgnoreReviewContentBySport'
	)
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiMapping ON #tmpInsertedNoti (NotificationID)
	
	CREATE TABLE #tmpResultInfo (
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
	CREATE CLUSTERED INDEX CIX_tmpResultInfo ON #tmpResultInfo (SettlementLogID)
	
	CREATE TABLE #tmpAffectedResult (
		SettlementLogID INT
		,RefBettypeID VARCHAR(50)
		,OtherInfo VARCHAR(50)
		,G VARCHAR(50)
		,X VARCHAR(50)
		,Y VARCHAR(50)
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	CREATE CLUSTERED INDEX CIX_tmpAffectedResult ON #tmpAffectedResult (SettlementLogID)
	
	/****************************************************************************
	
		#2.Get ValidSettleIDs and write log input params
		
	****************************************************************************/	
	EXEC MNC_ResultAmendment_GetSettlementLogIDs
		@Environment = @Environment
		,@JSRemotingRef = @JSRemotingRef
		,@ValidSettlementLogIDs = @ValidSettlementLogIDs OUTPUT
	
	--write more info both PROD/UAT if LogMode = Debug
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Start Generate Msg Notification with @UATMode = ' + @UATMode
					+ ', @ValidSettlementLogIDs('+ISNULL(@ValidSettlementLogIDs,'NULL')+')'
					+ ', @JSRemotingRef('+ISNULL(@JSRemotingRef,'NULL')+')'
	WHERE @LogMode = 'Debug'
	/****************************************************************************
		#3.Prepare data to generate message
			#tmpResultHist
			#tmpRemotingRef
			#tmpResultInfo
	****************************************************************************/
	BEGIN TRY
		;WITH CTE_SettleIDs AS (
			SELECT TRY_CONVERT(INT, value) AS SettlementLogID
			FROM STRING_SPLIT(@ValidSettlementLogIDs, ',')
		)
		INSERT INTO #tmpResultHist (
			SettlementLogID
			,StatusID
			,SessionID
			,SeqNo
			,MatchID
			,IsTest --get for NotificationExtra
			,EventDate
			,SportType
			,IsNeutral
			,HomeID
			,AwayID
			,KOTime
			,LeagueID
			,LeagueGroupID
			,GameSession
			,ActionType
			,ActualResultXML
			,WrongResultXML
		)
		SELECT i.SettlementLogID
			,sh.StatusID
			,sh.SessionID
			,sh.SeqNo
			,sh.MatchID
			,sh.IsTest --get for NotificationExtra
			,ISNULL(m.EventDate, m14.EventDate) AS EventDate
			,sh.SportType
			,ISNULL(m.IsNeutral, m14.IsNeutral) AS IsNeutral
			,ISNULL(m.HomeID, m14.HomeID) AS HomeID
			,ISNULL(m.AwayID, m14.AwayID) AS AwayID
			,COALESCE(m.kickofftime, m14.kickofftime, m.GlobalShowTime, m14.GlobalShowTime) AS KOTime
			,l.LeagueID
			,l.LeagueGroupID
			,l.GameSession
			,sh.ActionType
			,TRY_CONVERT(XML, sh.ActualResult) AS ActualResultXML
			,TRY_CONVERT(XML, sh.WrongResult) AS WrongResultXML
		FROM CTE_SettleIDs AS i
			INNER JOIN SettlementResultHist AS sh WITH (NOLOCK) ON i.SettlementLogID = sh.SettlementLogID
			LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
			LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
			LEFT JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON ISNULL(m.LeagueID, m14.LeagueID) = l.LeagueID
		WHERE sh.StatusID = @StsGenerating
			AND ISNULL(m.MatchID, m14.MatchID) IS NOT NULL
		
		--write log
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT SettlementLogID
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Prepare data to generate message after validating SettlementLogID'
		FROM #tmpResultHist
		WHERE @LogMode = 'Debug'
		ORDER BY SettlementLogID
		
		INSERT INTO #tmpRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
			,RefValueEN
			,RefValueCH
			,RefValueCS
		)
		SELECT DISTINCT value AS SettlementLogID
			,GroupName
			,RefId1
			,RefId2
			,RefValueEN
			,RefValueCH
			,RefValueCS
		FROM OPENJSON(@JSRemotingRef) WITH (
				SettlementLogIDs VARCHAR(MAX) '$.SettlementLogIDs'
				,GroupName VARCHAR(50) '$.GroupName'
				,RefId1 VARCHAR(50) '$.RefId1'
				,RefId2 VARCHAR(50) '$.RefId2'
				,RefValueEN NVARCHAR(500) '$.RefValueEN'
				,RefValueCH NVARCHAR(500) '$.RefValueCH'
				,RefValueCS NVARCHAR(500) '$.RefValueCS'
			)--OPENJSON case-sensitive
		CROSS APPLY STRING_SPLIT(SettlementLogIDs, ',')
		
		/*
			Parse data from ActualResult / WrongResult
				#tmpResultInfo
		*/
		EXEC MNC_ResultAmendment_JSParseResult
			@SettlementLogIDs = @ValidSettlementLogIDs
			,@ParseAmendInfo = 'ActualResult,WrongResult'
			,@ParseTo = 'RawData'
			,@OutJSResource = @JSResource OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
		
		INSERT INTO #tmpResultInfo (
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
			AND RefBettypeID IS NOT NULL
		
		--update AmendedCnt
		;WITH CTE_RefBettype AS (
			SELECT SettlementLogID
				,COUNT(DISTINCT RefBettypeID) AS AmendedCnt
			FROM #tmpResultInfo
			GROUP BY SettlementLogID
		)
		UPDATE rh
		SET rh.AmendedCnt = rb.AmendedCnt
		FROM #tmpResultHist AS rh
			INNER JOIN CTE_RefBettype AS rb ON rh.SettlementLogID = rb.SettlementLogID
		
		/*
			***************************************************<<<!IMPORTANT HARDCODE>>>***************************************************
			Mapping SettlementLogID vs TemplateID, output tables:
				#tmpNotiTarget (SettlementResultHistDetail with SMA + CustID)
				#tmpNoti (UNIQUE SettlementLogID, IsSabaFilter, ControlGrp, TemplateID)
				#tmpTemplateDetl
		*/
		/*----------#tmpNotiTarget------------
			IsSabaFilter = Saba
				+ LeagueGroupID IN (@SabaLeagueGroup)
				+ TargetSite belong to special sites
		*/
		;WITH CTE_SabaLG AS (
			SELECT TRY_CONVERT(INT,value) AS SabaLG
			FROM STRING_SPLIT(@SabaLeagueGroup, ',')
		)
		INSERT INTO #tmpNotiTarget (
			SettlementLogID
			,IsSabaFilter
			,ControlGrp
			,TargetSite
			,CustID
			,AgentID
			,MasterID
			,SuperID
			,TransID
		)
		SELECT DISTINCT rhd.SettlementLogID
			,(CASE WHEN (saba.value IS NOT NULL AND (ag.Site = '777777' OR s.IsChinaView = 1 OR s.SpecialPlatfrom > 0)) THEN 1
				ELSE 0 END) AS IsSabaFilter --0: Normal / 1: Saba
			,(CASE WHEN ag.Site = '777777' THEN 1
				ELSE 0 END) AS ControlGrp --0: OST / 1: 777
			,ag.Site AS TargetSite
			,rhd.CustID
			,c.recommend AS AgentID
			,c.mrecommend AS MasterID
			,c.srecommend AS SuperID
			,rhd.TransID
		FROM #tmpResultHist AS rh
			INNER JOIN SettlementResultHistDetail AS rhd WITH (NOLOCK) ON rhd.SettlementLogID = rh.SettlementLogID
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
			INNER JOIN bodb02.dbo.Customer AS ag WITH (NOLOCK) ON c.recommend = ag.CustID
			INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON ag.Site = s.Site
			LEFT JOIN STRING_SPLIT(@SabaLeagueGroup, ',') AS saba ON rh.LeagueGroupID = TRY_CONVERT(INT,saba.value)
		-- WHERE rh.SportType = 50 --Cricket
		
		/****************************************************<<<!IMPORTANT HARDCODE>>>***************************************************/
		;WITH CTE_Noti AS (
			SELECT DISTINCT rh.SettlementLogID
				,ntgt.IsSabaFilter
				,ntgt.ControlGrp
				,(CASE WHEN rh.ActionType = 1 AND rh.AmendedCnt = 1 THEN 3 --CAL to CAL, AmendedCnt=1
					WHEN rh.ActionType = 1 AND rh.AmendedCnt = 2 THEN 4 --CAL to CAL, AmendedCnt=2
					WHEN rh.ActionType = 1 AND rh.AmendedCnt > 2 THEN 5 --CAL to CAL, AmendedCnt = more than 2
					WHEN rh.ActionType IN (2,3) AND rh.AmendedCnt IN (1,2) THEN 1 --CAL to Refund / Refund to CAL, AmendedCnt = more than 2
					WHEN rh.ActionType IN (2,3) AND rh.AmendedCnt > 2 THEN 2 --CAL to Refund / Refund to CAL, AmendedCnt = more than 2
				END) AS TemplateID
			FROM #tmpResultHist AS rh
				INNER JOIN #tmpNotiTarget AS ntgt ON rh.SettlementLogID = ntgt.SettlementLogID
		)
		INSERT INTO #tmpNoti (
			SettlementLogID
			,IsSabaFilter
			,ControlGrp
			,TemplateID
			,Content_en
			,Content_ch
			,Content_cs
		)
		SELECT DISTINCT n.SettlementLogID
			,n.IsSabaFilter
			,n.ControlGrp
			,n.TemplateID
			,tp.Content_en
			,tp.Content_ch
			,tp.Content_cs
		FROM CTE_Noti AS n
			INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID
		
		----------#tmpTemplateDetl-------------
		;WITH CTE_ParseParam AS (
			SELECT TRIM(rq.value) AS RequiredParam
				,ROW_NUMBER() OVER (ORDER BY TRIM(rq.value) ) AS RequiredParamID --use for loop
			FROM #tmpNoti AS n
				INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID
				CROSS APPLY STRING_SPLIT(tp.RequiredParams, ',') AS rq
			WHERE ISNULL(TRIM(rq.value),'') <> ''
			GROUP BY TRIM(rq.value)
		)
		INSERT INTO #tmpTemplateDetl (
			SettlementLogID
			,IsSabaFilter
			,ControlGrp
			,RequiredParamID
			,RequiredParam
		)
		SELECT DISTINCT n.SettlementLogID
			,n.IsSabaFilter
			,n.ControlGrp
			,r.RequiredParamID
			,r.RequiredParam
		FROM #tmpNoti AS n
			INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID--re-join to make sure [1 RequiredParamID] : [1 RequiredParam]
			CROSS APPLY STRING_SPLIT(tp.RequiredParams, ',') AS rq
			INNER JOIN CTE_ParseParam AS r ON TRIM(rq.value) = r.RequiredParam

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Prepare data to generate message - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	/****************************************************************************
		#4.Start to Build message
		
		Build RequiredParam text of Template
			#tmpTemplateDetl
		
		Follow below rules in order
			1.If exists OtherInfo=""16776"", put it after the Resource_en
			2.If exists TeamIDs=""874484"" , don't care HomeValue - it's result (...result is "Ireland" instead of "Scotland"...)
			3.If HomeValue is number, it's result (...result is ""12,03"" instead of ""11,04""...)
			4.If HomeValue is NOT number, it's RefResource.RefId = 'ResultSettlement'"
	****************************************************************************/
	IF @ErrCode = 0
	BEGIN TRY
		/*
			----------{match_info}----------
			IsSabaFilter = 0: Normal / 1: Saba
			handle for special sites - REMOVE 'SABA'
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{match_info}')
		BEGIN
			;WITH CTE_MatchInfoDetl AS (
				SELECT tp.SettlementLogID
					,tp.IsSabaFilter
					,tp.ControlGrp
					,rfh.RefValueEN + (CASE WHEN rh.IsNeutral = 1 THEN N' ' + @Neutral_en ELSE '' END) AS HomeName_en
					,rfa.RefValueEN AS AwayName_en
					,(CASE WHEN tp.IsSabaFilter = 1 THEN REPLACE(rfl.RefValueEN,@Saba_en,'') --REMOVE 'SABA'
						ELSE rfl.RefValueEN END) AS LeagueName_en
					
					,rfh.RefValueCH + (CASE WHEN rh.IsNeutral = 1 THEN N' ' + @Neutral_ch ELSE '' END) AS HomeName_ch
					,rfa.RefValueCH AS AwayName_ch
					,(CASE WHEN tp.IsSabaFilter = 1 THEN REPLACE(rfl.RefValueCH,@Saba_ch,'') --REMOVE 'SABA'
						ELSE rfl.RefValueCH END) AS LeagueName_ch
					
					,rfh.RefValueCS + (CASE WHEN rh.IsNeutral = 1 THEN N' ' + @Neutral_cs ELSE '' END) AS HomeName_cs
					,rfa.RefValueCS AS AwayName_cs
					,(CASE WHEN tp.IsSabaFilter = 1 THEN REPLACE(rfl.RefValueCS,@Saba_cs,'') --REMOVE 'SABA'
						ELSE rfl.RefValueCS END) AS LeagueName_cs
					
					,CONVERT(VARCHAR(5),KOTime,103) AS KO_DDMM
				FROM #tmpTemplateDetl AS tp
					INNER JOIN #tmpResultHist AS rh ON tp.SettlementLogID = rh.SettlementLogID
					INNER JOIN #tmpRemotingRef AS rfh ON tp.SettlementLogID = rfh.SettlementLogID AND rfh.GroupName = 'EventInfo' AND rfh.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfh.RefId2) = rh.HomeID
					INNER JOIN #tmpRemotingRef AS rfa ON tp.SettlementLogID = rfa.SettlementLogID AND rfa.GroupName = 'EventInfo' AND rfa.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfa.RefId2) = rh.AwayID
					INNER JOIN #tmpRemotingRef AS rfl ON tp.SettlementLogID = rfl.SettlementLogID AND rfl.GroupName = 'EventInfo' AND rfl.RefId1 = 'LeagueID' AND TRY_CONVERT(INT,rfl.RefId2) = rh.LeagueID
				WHERE tp.RequiredParam = '{match_info}'
			)
			,CTE_MatchInfo AS (
				--Pattern: "@home_name -vs- @away_name" [@league_name - @ko_date]
				SELECT SettlementLogID
					,IsSabaFilter
					,ControlGrp
					,MAX('"' + HomeName_en + ' -vs- ' + AwayName_en + '" [' + LeagueName_en + ' - ' + KO_DDMM + ']') AS Content_en
					,MAX('"' + HomeName_ch + ' -vs- ' + AwayName_ch + '" [' + LeagueName_ch + ' - ' + KO_DDMM + ']') AS Content_ch
					,MAX('"' + HomeName_cs + ' -vs- ' + AwayName_cs + '" [' + LeagueName_cs + ' - ' + KO_DDMM + ']') AS Content_cs
				FROM CTE_MatchInfoDetl
				GROUP BY SettlementLogID --GROUP BY to make sure only 1 Content foreach SettlementLogID/IsSabaFilter
					,IsSabaFilter
					,ControlGrp
			)
			UPDATE tp
			SET tp.Content_en = m.Content_en
				,tp.Content_ch = m.Content_ch
				,tp.Content_cs = m.Content_cs
			FROM #tmpTemplateDetl AS tp
				INNER JOIN CTE_MatchInfo AS m ON tp.SettlementLogID = m.SettlementLogID AND tp.IsSabaFilter = m.IsSabaFilter AND tp.ControlGrp = m.ControlGrp
			WHERE tp.RequiredParam = '{match_info}'
		END
		
		/*
			{new_value}
				+ SettlementLogID only 1 RefBettypeID
					=> No need DISTINCT/GROUP BY SettlementLogID when select from RemotingRef
				+ DON'T care IsSabaFilter
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{new_value}')
		BEGIN
			--2.If exists TeamIDs
			;WITH CTE_TeamID AS (
				SELECT atl.SettlementLogID
					,rf.RefValueEN AS TeamName_en
					,rf.RefValueCH AS TeamName_ch
					,rf.RefValueCS AS TeamName_cs
				FROM #tmpResultInfo AS atl
					CROSS APPLY STRING_SPLIT(atl.TeamIDs, ',') AS t
					INNER JOIN #tmpRemotingRef AS rf ON atl.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = t.value
				WHERE atl.AmendInfo = 'ActualResult'
					AND TRY_CONVERT(INT,t.value) IS NOT NULL
			)
			UPDATE tp
			SET tp.Content_en = t.TeamName_en
				,tp.Content_ch = t.TeamName_ch
				,tp.Content_cs = t.TeamName_cs
			FROM #tmpTemplateDetl AS tp
				INNER JOIN CTE_TeamID AS t ON tp.SettlementLogID = t.SettlementLogID
			WHERE tp.RequiredParam = '{new_value}'
			
			--3.If HomeValue is number
			UPDATE tp
			SET tp.Content_en = atl.HomeValue
				,tp.Content_ch = atl.HomeValue
				,tp.Content_cs = atl.HomeValue
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpResultInfo AS atl ON tp.SettlementLogID = atl.SettlementLogID
			WHERE atl.AmendInfo = 'ActualResult'
				AND tp.RequiredParam = '{new_value}'
				AND tp.Content_en IS NULL
				AND tp.Content_ch IS NULL
				AND tp.Content_cs IS NULL
				AND ISNUMERIC(REPLACE(ISNULL(atl.HomeValue,''),',','')) = 1
			
			--4.If HomeValue is NOT number
			UPDATE tp
			SET tp.Content_en = rf.RefValueEN
				,tp.Content_ch = rf.RefValueCH
				,tp.Content_cs = rf.RefValueCS
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpResultInfo AS atl ON tp.SettlementLogID = atl.SettlementLogID
				INNER JOIN #tmpRemotingRef AS rf ON tp.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResultSettlement' AND rf.RefId2 = atl.HomeValue
			WHERE atl.AmendInfo = 'ActualResult'
				AND tp.RequiredParam = '{new_value}'
				AND tp.Content_en IS NULL
				AND tp.Content_ch IS NULL
				AND tp.Content_cs IS NULL
				AND ISNUMERIC(REPLACE(ISNULL(atl.HomeValue,''),',','')) = 0
			
			--5.the rest, value of HomeValue
			UPDATE tp
			SET tp.Content_en = atl.HomeValue
				,tp.Content_ch = atl.HomeValue
				,tp.Content_cs = atl.HomeValue
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpResultInfo AS atl ON tp.SettlementLogID = atl.SettlementLogID
			WHERE atl.AmendInfo = 'ActualResult'
				AND tp.RequiredParam = '{new_value}'
				AND tp.Content_en IS NULL
				AND tp.Content_ch IS NULL
				AND tp.Content_cs IS NULL
		END
		
		/*
			{old_value}
				+ SettlementLogID only 1 RefBettypeID
					=> No need DISTINCT/GROUP BY SettlementLogID when select from RemotingRef
				+ DON'T care IsSabaFilter
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{old_value}')
		BEGIN
			--2.If exists TeamIDs
			;WITH CTE_TeamID AS (
				SELECT wrg.SettlementLogID
					,rf.RefValueEN AS TeamName_en
					,rf.RefValueCH AS TeamName_ch
					,rf.RefValueCS AS TeamName_cs
				FROM #tmpResultInfo AS wrg
					CROSS APPLY STRING_SPLIT(wrg.TeamIDs, ',') AS t
					INNER JOIN #tmpRemotingRef AS rf ON wrg.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = t.value
				WHERE wrg.AmendInfo = 'WrongResult'
					AND TRY_CONVERT(INT,t.value) IS NOT NULL
			)
			UPDATE tp
			SET tp.Content_en = t.TeamName_en
				,tp.Content_ch = t.TeamName_ch
				,tp.Content_cs = t.TeamName_cs
			FROM #tmpTemplateDetl AS tp
				INNER JOIN CTE_TeamID AS t ON tp.SettlementLogID = t.SettlementLogID
			WHERE tp.RequiredParam = '{old_value}'
			
			--3.If HomeValue is number
			UPDATE tp
			SET tp.Content_en = wrg.HomeValue
				,tp.Content_ch = wrg.HomeValue
				,tp.Content_cs = wrg.HomeValue
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpResultInfo AS wrg ON tp.SettlementLogID = wrg.SettlementLogID
			WHERE wrg.AmendInfo = 'WrongResult'
				AND tp.RequiredParam = '{old_value}'
				AND tp.Content_en IS NULL
				AND tp.Content_ch IS NULL
				AND tp.Content_cs IS NULL
				AND ISNUMERIC(REPLACE(ISNULL(wrg.HomeValue,''),',','')) = 1
			
			--4.If HomeValue is NOT number
			UPDATE tp
			SET tp.Content_en = rf.RefValueEN
				,tp.Content_ch = rf.RefValueCH
				,tp.Content_cs = rf.RefValueCS
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpResultInfo AS wrg ON tp.SettlementLogID = wrg.SettlementLogID
				INNER JOIN #tmpRemotingRef AS rf ON tp.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResultSettlement' AND rf.RefId2 = wrg.HomeValue
			WHERE wrg.AmendInfo = 'WrongResult'
				AND tp.RequiredParam = '{old_value}'
				AND tp.Content_en IS NULL
				AND tp.Content_ch IS NULL
				AND tp.Content_cs IS NULL
				AND ISNUMERIC(REPLACE(ISNULL(wrg.HomeValue,''),',','')) = 0
			
			--5.the rest, value of HomeValue
			UPDATE tp
			SET tp.Content_en = wrg.HomeValue
				,tp.Content_ch = wrg.HomeValue
				,tp.Content_cs = wrg.HomeValue
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpResultInfo AS wrg ON tp.SettlementLogID = wrg.SettlementLogID
			WHERE wrg.AmendInfo = 'WrongResult'
				AND tp.RequiredParam = '{old_value}'
				AND tp.Content_en IS NULL
				AND tp.Content_ch IS NULL
				AND tp.Content_cs IS NULL
		END
		
		----------{sport_name}----------
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{sport_name}')
		BEGIN
			UPDATE tp
			SET tp.Content_en = rf.RefValueEN
				,tp.Content_ch = rf.RefValueCH
				,tp.Content_cs = rf.RefValueCS
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpResultHist AS rh ON tp.SettlementLogID = rh.SettlementLogID
				INNER JOIN #tmpRemotingRef AS rf ON tp.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'EventInfo' AND rf.RefId1 = 'SportType' AND TRY_CONVERT(INT,rf.RefId2) = rh.SportType
			WHERE tp.RequiredParam = '{sport_name}'
		END
		
		----------{affected_result_name}----------
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{affected_result_name}')
		BEGIN
			--step #1 - get Resource_en / Resource_ch / Resource_cs
			INSERT INTO #tmpAffectedResult (
				SettlementLogID
				,RefBettypeID
				,OtherInfo
				,G
				,X
				,Y
				,Content_en
				,Content_ch
				,Content_cs
			)
			SELECT DISTINCT tp.SettlementLogID
				,ISNULL(atl.RefBettypeID, wrg.RefBettypeID) AS RefBettypeID
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.OtherInfo ELSE wrg.OtherInfo END AS OtherInfo
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.G ELSE wrg.G END AS G
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.X ELSE wrg.X END AS X
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.Y ELSE wrg.Y END AS Y
				,rf.RefValueEN AS Content_en
				,rf.RefValueCH AS Content_ch
				,rf.RefValueCS AS Content_cs
			FROM #tmpTemplateDetl AS tp
				LEFT JOIN #tmpResultInfo AS atl ON tp.SettlementLogID = atl.SettlementLogID AND atl.AmendInfo = 'ActualResult'
				LEFT JOIN #tmpResultInfo AS wrg ON tp.SettlementLogID = wrg.SettlementLogID AND wrg.AmendInfo = 'WrongResult'
				INNER JOIN #tmpRemotingRef AS rf ON tp.SettlementLogID = rf.SettlementLogID AND rf.RefId2 = ISNULL(atl.RefBettypeID, wrg.RefBettypeID)
			WHERE ISNULL(atl.RefBettypeID, wrg.RefBettypeID) IS NOT NULL
				AND tp.RequiredParam = '{affected_result_name}'
				AND rf.GroupName = 'RefResource'
				AND rf.RefId1 = 'ResourceCricket'
			
			--step #2 - Replace X / Y
			UPDATE #tmpAffectedResult
			SET Content_en = REPLACE(Content_en,'@X',X)
				,Content_ch = REPLACE(Content_ch,'@X',X)
				,Content_cs = REPLACE(Content_cs,'@X',X)
			WHERE ISNULL(CHARINDEX('@X',Content_en),0) > 0
				OR ISNULL(CHARINDEX('@X',Content_ch),0) > 0
				OR ISNULL(CHARINDEX('@X',Content_cs),0) > 0
			
			UPDATE #tmpAffectedResult
			SET Content_en = REPLACE(Content_en,'@Y',Y)
				,Content_ch = REPLACE(Content_ch,'@Y',Y)
				,Content_cs = REPLACE(Content_cs,'@Y',Y)
			WHERE ISNULL(CHARINDEX('@Y',Content_en),0) > 0
				OR ISNULL(CHARINDEX('@Y',Content_ch),0) > 0
				OR ISNULL(CHARINDEX('@Y',Content_cs),0) > 0
			
			--step #2 - 2.1 Replace G / M for GameSession IN (1,8) - match 2 inning
			;WITH CTE_G_Inns AS (
				SELECT af.SettlementLogID
					,af.RefBettypeID
					,'G' + af.G AS rG --Handle case 1 inning only later
				FROM #tmpAffectedResult AS af
					INNER JOIN #tmpResultHist AS rh ON af.SettlementLogID = rh.SettlementLogID AND rh.GameSession IN (1,8)
				WHERE ISNULL(CHARINDEX('@G',af.Content_en),0) > 0
					OR ISNULL(CHARINDEX('@G',af.Content_ch),0) > 0
					OR ISNULL(CHARINDEX('@G',af.Content_cs),0) > 0
			)
			UPDATE af
			SET Content_en = REPLACE(af.Content_en,'@G',rf.RefValueEN)
				,Content_ch = REPLACE(af.Content_ch,'@G',rf.RefValueCH)
				,Content_cs = REPLACE(af.Content_cs,'@G',rf.RefValueCS)
			FROM #tmpAffectedResult AS af
				INNER JOIN CTE_G_Inns AS inn ON af.SettlementLogID = inn.SettlementLogID AND af.RefBettypeID = inn.RefBettypeID
				LEFT JOIN #tmpRemotingRef AS rf ON af.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResourceCricket' AND rf.RefId2 = inn.rG
			
			;WITH CTE_M_Inns AS (
				SELECT af.SettlementLogID
					,af.RefBettypeID
					,'M' + af.G AS rM --Handle case 1 inning only later
				FROM #tmpAffectedResult AS af
					INNER JOIN #tmpResultHist AS rh ON af.SettlementLogID = rh.SettlementLogID AND rh.GameSession IN (1,8)
				WHERE ISNULL(CHARINDEX('@M',af.Content_en),0) > 0
					OR ISNULL(CHARINDEX('@M',af.Content_ch),0) > 0
					OR ISNULL(CHARINDEX('@M',af.Content_cs),0) > 0
			)
			UPDATE af
			SET Content_en = REPLACE(af.Content_en,'@M',ISNULL(rf.RefValueEN,''))
				,Content_ch = REPLACE(af.Content_ch,'@M',ISNULL(rf.RefValueCH,''))
				,Content_cs = REPLACE(af.Content_cs,'@M',ISNULL(rf.RefValueCS,''))
			FROM #tmpAffectedResult AS af
				INNER JOIN CTE_M_Inns AS inn ON af.SettlementLogID = inn.SettlementLogID AND af.RefBettypeID = inn.RefBettypeID
				LEFT JOIN #tmpRemotingRef AS rf ON af.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResourceCricket' AND rf.RefId2 = inn.rM
			
			----step #2 - 2.2 Replace G / M for GameSession NOT IN (1,8) - match 1 inning only
			UPDATE #tmpAffectedResult
			SET Content_en = REPLACE(REPLACE(Content_en,' @G ',' '),'@G','')
				,Content_ch = REPLACE(REPLACE(Content_ch,' @G ',' '),'@G','')
				,Content_cs = REPLACE(REPLACE(Content_cs,' @G ',' '),'@G','')
			
			UPDATE #tmpAffectedResult
			SET Content_en = REPLACE(REPLACE(Content_en,' @M ',' '),'@M','')
				,Content_ch = REPLACE(REPLACE(Content_ch,' @M ',' '),'@M','')
				,Content_cs = REPLACE(REPLACE(Content_cs,' @M ',' '),'@M','')
			
			--step #4 - rule#1.If exists OtherInfo => put it after the Resource_en
			;WITH CTE_OtherInfo AS (
				SELECT af.SettlementLogID
					,af.RefBettypeID
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueEN),',') AS r_en
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueCH),',') AS r_ch
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueCS),',') AS r_cs
				FROM #tmpAffectedResult AS af
					CROSS APPLY STRING_SPLIT(OtherInfo, ',') AS o
					INNER JOIN #tmpRemotingRef AS rf ON af.SettlementLogID = rf.SettlementLogID AND rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = o.value
				WHERE TRY_CONVERT(INT,o.value) IS NOT NULL
				GROUP BY af.SettlementLogID
					,af.RefBettypeID
			)
			UPDATE af
			SET af.Content_en = af.Content_en + ' - ' + TRIM(o.r_en)
				,af.Content_ch = af.Content_ch + ' - ' + TRIM(o.r_ch)
				,af.Content_cs = af.Content_cs + ' - ' + TRIM(o.r_cs)
			FROM #tmpAffectedResult AS af
				INNER JOIN CTE_OtherInfo AS o ON af.SettlementLogID = o.SettlementLogID AND af.RefBettypeID = o.RefBettypeID
			
			---------final affected_result_name---------
			;WITH CTE_Affected AS (
				SELECT SettlementLogID
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(Content_en,'')),',') AS Content_en
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(Content_ch,'')),',') AS Content_ch
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(Content_cs,'')),',') AS Content_cs
				FROM #tmpAffectedResult
				GROUP BY SettlementLogID
			)
			UPDATE tp
			SET tp.Content_en = af.Content_en
				,tp.Content_ch = af.Content_ch
				,tp.Content_cs = af.Content_cs
			FROM #tmpTemplateDetl AS tp
				INNER JOIN CTE_Affected AS af ON tp.SettlementLogID = af.SettlementLogID
			WHERE tp.RequiredParam = '{affected_result_name}'
		END
		
		/*
			Build message content
				#tmpNoti
		*/
		SET @iLoop = 1
		WHILE EXISTS(SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParamID = @iLoop)
		BEGIN
			--Start to replace RequiredParams
			UPDATE ms
			SET ms.Content_en = REPLACE(ms.Content_en,tpd.RequiredParam,tpd.Content_en)
				,ms.Content_ch = REPLACE(ms.Content_ch,tpd.RequiredParam,tpd.Content_ch)
				,ms.Content_cs = REPLACE(ms.Content_cs,tpd.RequiredParam,tpd.Content_cs)
			FROM #tmpNoti AS ms
				INNER JOIN #tmpTemplateDetl AS tpd ON ms.SettlementLogID = tpd.SettlementLogID AND ms.IsSabaFilter = tpd.IsSabaFilter
			WHERE tpd.RequiredParamID = @iLoop
			
			SET @iLoop = @iLoop + 1
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Build message content - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	--write log
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT SettlementLogID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Build message content compelted - Content_en(' + ISNULL(Content_en,'NULL') + ')'
	FROM #tmpNoti
	WHERE @LogMode = 'Debug'
	ORDER BY SettlementLogID
	
	/****************************************************************************
		#5.Handle for duplicate Content_en and Prepare for insert
	****************************************************************************/
	IF @ErrCode = 0
	BEGIN TRY
		/*
			Remove duplicate Content_en by [SessionID] / [Content] / [user control group]
				+ [Session] 						= SessionID, MatchID
				+ [Content] = [SeqNo,IsSabaFilter] 	= Content_en
				+ [user control group] 				= ControlGrp
			
			=> GROUP BY SessionID, MatchID, Content_en, ControlGrp
		*/
		;WITH CTE_PrepareIns AS (
			SELECT rh.SessionID
				,rh.MatchID
				,n.Content_en
				,n.ControlGrp
				,ROW_NUMBER() OVER (ORDER BY rh.SessionID, rh.MatchID, n.Content_en, n.ControlGrp) AS GrpID --define [GrpID] of message content
			FROM #tmpResultHist AS rh
				INNER JOIN #tmpNoti AS n ON rh.SettlementLogID = n.SettlementLogID
				INNER JOIN #tmpNotiTarget AS ntgt ON n.SettlementLogID = ntgt.SettlementLogID AND n.IsSabaFilter = ntgt.IsSabaFilter AND n.ControlGrp = ntgt.ControlGrp
			WHERE rh.StatusID = @StsGenerating
				AND ISNULL(TRIM(n.Content_en),'') + ISNULL(TRIM(n.Content_ch),'') + ISNULL(TRIM(n.Content_cs),'') <> '' --Content is not BLANK
			GROUP BY rh.SessionID
				,rh.MatchID
				,n.Content_en
				,n.ControlGrp
		)
		INSERT INTO #tmpPrepareInsertNoti (
			GrpID
			,SettlementLogID
			,IsSabaFilter
			,ControlGrp
		)
		--parse CTE_PrepareIns.GrpID => UNIQUE KEY OF #tmpPrepareInsertNoti
		SELECT DISTINCT i.GrpID
			,n.SettlementLogID
			,n.IsSabaFilter
			,n.ControlGrp
		FROM CTE_PrepareIns AS i
			INNER JOIN #tmpResultHist AS rh ON rh.SessionID = i.SessionID AND rh.MatchID = i.MatchID
			INNER JOIN #tmpNoti AS n ON n.Content_en = i.Content_en AND n.ControlGrp = i.ControlGrp AND n.SettlementLogID = rh.SettlementLogID
		
		/*
			Verify again with #tmpPrepareInsertNoti
				- In case SettlementLogID have 3 noti for Normal,Saba and 777
					+ 1 of those failed => SettlementLogID will be failed
		*/
		;WITH CTE_Check AS (
			SELECT i.GrpID
				,MIN(CASE --WHEN i.SettlementLogID IS NULL THEN 0
						WHEN n.SettlementLogID IS NULL THEN 1
						WHEN ntgt.SettlementLogID IS NULL THEN 2
						ELSE 3 END) AS ValidSts --MUST EXISTS Noti / NotiTarget
			FROM #tmpPrepareInsertNoti AS i
				LEFT JOIN #tmpNoti AS n ON i.SettlementLogID = n.SettlementLogID AND i.IsSabaFilter = n.IsSabaFilter AND i.ControlGrp = n.ControlGrp
				LEFT JOIN #tmpNotiTarget AS ntgt ON i.SettlementLogID = ntgt.SettlementLogID AND i.IsSabaFilter = ntgt.IsSabaFilter AND i.ControlGrp = ntgt.ControlGrp
			GROUP BY i.GrpID
		)
		UPDATE rh
		SET rh.StatusID = CASE WHEN (rh.StatusID = @StsGenerating AND ISNULL(ck.ValidSts,0) = 3) THEN @StsGenerating ELSE @StsGenFailed END
			,rh.NotiLogBef = rh.NotiLogBef
							+ (CASE WHEN rh.StatusID <> @StsGenerating THEN 'Before INS Notification - temp Status' + ISNULL(CONVERT(VARCHAR,rh.StatusID),'NULL') + ' - NOT [Generating]'
								WHEN i.SettlementLogID IS NULL OR ISNULL(ck.ValidSts,0) = 0 THEN 'Before INS Notification - NOT EIXSTS IN temporary insert list'
								WHEN ck.ValidSts = 1 THEN 'Before INS Notification - Missing S.T while creating Notification (ex: SettlementLogID have 3 Noti (Normal,Saba and 777) but have NO [Saba] in #tmpNoti)'
								WHEN ck.ValidSts = 2 THEN 'Before INS Notification - Missing S.T while creating NotificationTarget (have NO data in #tmpNotiTarget)'
								ELSE '' --Ready for insert NotiMapping / Notification / NotificationTarget
								END)
		FROM #tmpResultHist AS rh
			LEFT JOIN #tmpPrepareInsertNoti AS i ON rh.SettlementLogID = i.SettlementLogID
			LEFT JOIN CTE_Check AS ck ON i.GrpID = ck.GrpID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Handle duplicate Content - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	/****************************************************************************
		#6.Start to insert data
			Notification
			NotificationTarget
			NotificationExtra
			NotiMapping
	****************************************************************************/
	IF @ErrCode = 0
	BEGIN TRY
		--insert Notification by GrpID (foreach row) to get [IDENTITY NotificationID] + [GrpID]
		SELECT @iLoop = MIN(GrpID)
		FROM #tmpPrepareInsertNoti
		
		WHILE EXISTS(SELECT 1 FROM #tmpPrepareInsertNoti WHERE GrpID = @iLoop)
		BEGIN
			;WITH CTE_InsertNoti AS (
				SELECT TOP 1 SettlementLogID --only insert 1 Content for group of the same message content
					,IsSabaFilter
					,ControlGrp
				FROM #tmpPrepareInsertNoti
				WHERE GrpID = @iLoop
			)
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
				NotificationID
				,GrpID
			) --Get Inserted
			SELECT rh.StatusID --Generating
				,1 AS NotificationType --Result Amendment to Msg
				,tp.TemplateName AS Subject
				,n.Content_en
				,n.Content_ch
				,n.Content_cs
			FROM CTE_InsertNoti AS il
				INNER JOIN #tmpNoti AS n ON il.SettlementLogID = n.SettlementLogID AND il.IsSabaFilter = n.IsSabaFilter AND il.ControlGrp = n.ControlGrp
				LEFT JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID
				INNER JOIN #tmpResultHist AS rh ON il.SettlementLogID = rh.SettlementLogID
			WHERE rh.StatusID = @StsGenerating
			
			--increase for loop
			SET @iLoop = (SELECT MIN(GrpID) FROM #tmpPrepareInsertNoti WHERE GrpID > @iLoop)
		END
		
		---Dynamic StatusID by SystemSetting.VName = 'IgnoreReviewContentBySport'
		;WITH CTE_Noti_Status AS (
			SELECT DISTINCT i.NotificationID
				/*
					IF SportType EXISTS IN SystemSetting.VName = 'IgnoreReviewContentBySport'
						=> SuccessStatusID = 'Sending' => Ignore Review
					ELSE
						=> SuccessStatusID = 'New' => Need to review before push to Msg/MsgTarget
					
					***#tmpInsertedNoti.GrpID ONLY 1 MatchID => ONLY 1 SportType
				*/
				,(CASE WHEN cs.value IS NOT NULL THEN @StsSending
					ELSE @StsNew END) AS SuccessStatusID
			FROM #tmpInsertedNoti AS i
				INNER JOIN #tmpPrepareInsertNoti AS pr ON i.GrpID = pr.GrpID
				INNER JOIN #tmpResultHist AS rh ON pr.SettlementLogID = rh.SettlementLogID
				LEFT JOIN STRING_SPLIT((SELECT VValue FROM dbo.SystemSetting WITH (NOLOCK) WHERE VID = 3), ',') AS cs ON rh.SportType = TRY_CONVERT(INT,cs.value)
		)
		UPDATE i
		SET i.SuccessStatusID = s.SuccessStatusID
		FROM #tmpInsertedNoti AS i
			INNER JOIN CTE_Noti_Status AS s ON i.NotificationID = s.NotificationID
			
		/*
			Insert NotificationTarget
		*/
		;WITH CTE_AllTarget AS (
			--TranIDs by CustID
			SELECT s.GrpID
				,ntgt.CustID AS TargetID
				,ntgt.TargetSite
				,CONVERT(NVARCHAR(MAX),(
							SELECT DISTINCT t.TransID
							FROM #tmpPrepareInsertNoti AS st
								INNER JOIN #tmpNotiTarget AS t ON st.SettlementLogID = t.SettlementLogID AND st.IsSabaFilter = t.IsSabaFilter AND st.ControlGrp = t.ControlGrp
							WHERE s.GrpID = st.GrpID
								AND t.CustID = ntgt.CustID --TranIDs by CustID
								AND t.TargetSite = ntgt.TargetSite
							ORDER BY t.TransID
							FOR JSON AUTO
						)) AS TransIDs
			FROM #tmpPrepareInsertNoti AS s
				INNER JOIN #tmpNotiTarget AS ntgt ON s.SettlementLogID = ntgt.SettlementLogID AND s.IsSabaFilter = ntgt.IsSabaFilter AND s.ControlGrp = ntgt.ControlGrp
			GROUP BY s.GrpID
				,ntgt.CustID
				,ntgt.TargetSite

			UNION ALL
			
			--TranIDs by AgentID
			SELECT s.GrpID
				,ntgt.AgentID AS TargetID
				,ntgt.TargetSite
				,CONVERT(NVARCHAR(MAX),(
							SELECT DISTINCT t.TransID
							FROM #tmpPrepareInsertNoti AS st
								INNER JOIN #tmpNotiTarget AS t ON st.SettlementLogID = t.SettlementLogID AND st.IsSabaFilter = t.IsSabaFilter AND st.ControlGrp = t.ControlGrp
							WHERE s.GrpID = st.GrpID
								AND t.AgentID = ntgt.AgentID --TranIDs by AgentID
								AND t.TargetSite = ntgt.TargetSite
							ORDER BY t.TransID
							FOR JSON AUTO
						)) AS TransIDs
			FROM #tmpPrepareInsertNoti AS s
				INNER JOIN #tmpNotiTarget AS ntgt ON s.SettlementLogID = ntgt.SettlementLogID AND s.IsSabaFilter = ntgt.IsSabaFilter AND s.ControlGrp = ntgt.ControlGrp
			GROUP BY s.GrpID
				,ntgt.AgentID
				,ntgt.TargetSite
			
			UNION ALL
			
			--TranIDs by MasterID
			SELECT s.GrpID
				,ntgt.MasterID AS TargetID
				,ntgt.TargetSite
				,CONVERT(NVARCHAR(MAX),(
							SELECT DISTINCT t.TransID
							FROM #tmpPrepareInsertNoti AS st
								INNER JOIN #tmpNotiTarget AS t ON st.SettlementLogID = t.SettlementLogID AND st.IsSabaFilter = t.IsSabaFilter AND st.ControlGrp = t.ControlGrp
							WHERE s.GrpID = st.GrpID
								AND t.MasterID = ntgt.MasterID --TranIDs by MasterID
								AND t.TargetSite = ntgt.TargetSite
							ORDER BY t.TransID
							FOR JSON AUTO
						)) AS TransIDs
			FROM #tmpPrepareInsertNoti AS s
				INNER JOIN #tmpNotiTarget AS ntgt ON s.SettlementLogID = ntgt.SettlementLogID AND s.IsSabaFilter = ntgt.IsSabaFilter AND s.ControlGrp = ntgt.ControlGrp
			GROUP BY s.GrpID
				,ntgt.MasterID
				,ntgt.TargetSite
			
			UNION ALL
			
			--TranIDs by SuperID
			SELECT s.GrpID
				,ntgt.SuperID AS TargetID
				,ntgt.TargetSite
				,CONVERT(NVARCHAR(MAX),(
							SELECT DISTINCT t.TransID
							FROM #tmpPrepareInsertNoti AS st
								INNER JOIN #tmpNotiTarget AS t ON st.SettlementLogID = t.SettlementLogID AND st.IsSabaFilter = t.IsSabaFilter AND st.ControlGrp = t.ControlGrp
							WHERE s.GrpID = st.GrpID
								AND t.SuperID = ntgt.SuperID --TranIDs by SuperID
								AND t.TargetSite = ntgt.TargetSite
							ORDER BY t.TransID
							FOR JSON AUTO
						)) AS TransIDs
			FROM #tmpPrepareInsertNoti AS s
				INNER JOIN #tmpNotiTarget AS ntgt ON s.SettlementLogID = ntgt.SettlementLogID AND s.IsSabaFilter = ntgt.IsSabaFilter AND s.ControlGrp = ntgt.ControlGrp
			GROUP BY s.GrpID
				,ntgt.SuperID
				,ntgt.TargetSite
		)
		INSERT INTO NotificationTarget (
			NotificationID
			,StatusID
			,TargetID
			,TargetSite
			,ExtraInfo
		)
		SELECT i.NotificationID
			,i.SuccessStatusID AS StatusID
			,tgt.TargetID
			,tgt.TargetSite
			,tgt.TransIDs
		FROM #tmpInsertedNoti AS i
			INNER JOIN CTE_AllTarget AS tgt ON i.GrpID = tgt.GrpID
			
		/*
			Insert NotiMapping
		*/
		INSERT INTO NotiMapping (
			SettlementLogID
			,NotificationID
		)
		SELECT DISTINCT ig.SettlementLogID
			,i.NotificationID
		FROM #tmpInsertedNoti AS i --from Inserted NotificationID --> retrive GrpID -> SettlementLogID
			INNER JOIN #tmpPrepareInsertNoti AS ig ON i.GrpID = ig.GrpID
		
		/*
			Insert NotificationExtra
		*/
		INSERT INTO NotificationExtra (
			NotificationID
			,EventDate
			,ExtraInfo
		)
		SELECT DISTINCT i.NotificationID
			,rh.EventDate
			,CONVERT(NVARCHAR(MAX),(
				SELECT DISTINCT t.MatchID
					,t.IsTest
					,t.LeagueGroupID
					,t.KOTime
					,t.AmendedCnt
					,t.ActionType
					,t.GameSession
					,t.IsNeutral
					,CASE WHEN t.IsNeutral = 1 THEN @Neutral_en END AS NeutralEN
					,CASE WHEN t.IsNeutral = 1 THEN @Neutral_ch END AS NeutralCH
					,CASE WHEN t.IsNeutral = 1 THEN @Neutral_cs END AS NeutralCS
					,t.HomeID
					,rfh.RefValueEN AS HomeNameEN
					,rfh.RefValueCH AS HomeNameCH
					,rfh.RefValueCS AS HomeNameCS
					,t.AwayID
					,rfa.RefValueEN AS AwayNameEN
					,rfa.RefValueCH AS AwayNameCH
					,rfa.RefValueCS AS AwayNameCS
					,t.LeagueID
					,(CASE WHEN il.IsSabaFilter = 1 THEN REPLACE(rfl.RefValueEN,@Saba_en,'') --REMOVE 'SABA'
						ELSE rfl.RefValueEN END) AS LeagueNameEN
					,(CASE WHEN il.IsSabaFilter = 1 THEN REPLACE(rfl.RefValueCS,@Saba_en,'') --REMOVE 'SABA'
						ELSE rfl.RefValueCS END) AS LeagueNameCS
					,(CASE WHEN il.IsSabaFilter = 1 THEN REPLACE(rfl.RefValueCH,@Saba_en,'') --REMOVE 'SABA'
						ELSE rfl.RefValueCH END) AS LeagueNameCH
					,t.SportType
					,rfs.RefValueEN AS SportNameEN
					,rfs.RefValueCH AS SportNameCH
					,rfs.RefValueCS AS SportNameCS
					,c.username AS MsgSender
					,CASE WHEN c.username IS NOT NULL THEN GETDATE() END AS MsgSendDate
				FROM #tmpResultHist AS t
					LEFT JOIN #tmpRemotingRef AS rfh ON t.SettlementLogID = rfh.SettlementLogID AND rfh.GroupName = 'EventInfo' AND rfh.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfh.RefId2) = t.HomeID
					LEFT JOIN #tmpRemotingRef AS rfa ON t.SettlementLogID = rfa.SettlementLogID AND rfa.GroupName = 'EventInfo' AND rfa.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfa.RefId2) = t.AwayID
					LEFT JOIN #tmpRemotingRef AS rfl ON t.SettlementLogID = rfl.SettlementLogID AND rfl.GroupName = 'EventInfo' AND rfl.RefId1 = 'LeagueID' AND TRY_CONVERT(INT,rfl.RefId2) = t.LeagueID
					LEFT JOIN #tmpRemotingRef AS rfs ON t.SettlementLogID = rfs.SettlementLogID AND rfs.GroupName = 'EventInfo' AND rfs.RefId1 = 'SportType' AND TRY_CONVERT(INT,rfs.RefId2) = t.SportType
					LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.CustID = @LogUserID AND i.SuccessStatusID = @StsSending --Sender = [configurated Executor] if IgnoreReviewContent
				WHERE t.SettlementLogID = il.SettlementLogID
				FOR JSON PATH
			)) AS ExtraInfo
		FROM #tmpInsertedNoti AS i
			INNER JOIN #tmpPrepareInsertNoti AS il ON i.GrpID = il.GrpID
			INNER JOIN #tmpResultHist AS rh ON il.SettlementLogID = rh.SettlementLogID
		
		/*
			Start to final update Notification.StatusID
		*/
		
		-- Check after insert NotiMapping / Notification / NotificationTarget
			-- + Update Notification StatusID = SuccessStatusID
		;WITH CTE_Valid AS (
			SELECT DISTINCT n.NotificationID
				,i.SuccessStatusID
			FROM Notification AS n
				INNER JOIN NotificationTarget AS nt ON n.NotificationID = nt.NotificationID
				INNER JOIN NotiMapping AS nm ON nt.NotificationID = nm.NotificationID
				INNER JOIN #tmpInsertedNoti AS i ON nm.NotificationID = i.NotificationID
			WHERE n.StatusID = @StsGenerating
		)
		UPDATE n
		SET n.StatusID = v.SuccessStatusID --based on IgnoreReviewContentBySport
		FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
			INNER JOIN CTE_Valid AS v ON n.NotificationID = v.NotificationID
		
		--write log
		;WITH CTE_Settl AS (
			SELECT i.NotificationID
				,STRING_AGG(CONVERT(VARCHAR(MAX),nm.SettlementLogID),',') AS Settls
			FROM #tmpInsertedNoti AS i
				INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON i.NotificationID = nm.NotificationID
			GROUP BY i.NotificationID
		)
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT i.NotificationID
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Created Notification Msg with StatusID = ' + ISNULL(st.Status,CONVERT(VARCHAR,n.StatusID)) + ' - NotiMapping.SettlementLogID(' + ISNULL(s.Settls,'NULL') + ')'
		FROM #tmpInsertedNoti AS i
			INNER JOIN Notification AS n WITH (NOLOCK) ON i.NotificationID = n.NotificationID
			LEFT JOIN CTE_Settl AS s ON i.NotificationID = s.NotificationID
			LEFT JOIN NotiStatus AS st WITH (NOLOCK) ON n.StatusID = st.StatusID
		ORDER BY i.NotificationID
		
		/*	the rest, change to Failed
			
			because [1 SettlementLogID have many NotificationID(normal, saba)] AND [1 NotificationID have many SettlementLogID(3 SiteDBs)]
				=> SettlementLogID vs NotificationID is Many:Many relationship
				Ex:
					---------------|------------|----------			|		---------------|------------|----------
					SettlementLogID|IsSabaFilter|Status				| 		 NotificationID|IsSabaFilter|Status
					---------------|------------|----------			| 		---------------|------------|----------
								1  |          0 |Generating			|					8  |          0 |Failed to Generate
								2  |          0 |Generating			|					   |			|
								------------------------------------VS---------------------------------------------
								1  |          1 |Generating			|					9  |          1 |Sending
								2  |          1 |Generating			|					   |			|
					
					***	From NotificationID(8).Status = Failed to Generate => SettlementLogID(1,2).Status = Failed to Generate
							=> From SettlementLogID(1,2).Status = Failed to Generate => NotificationID(9).Status = Failed to Generate
				
				
			1.UPD #tmpResultHist "Success" / "Failed" (check with Notification)	***[From NotificationID(8).Status = Failed to Generate => SettlementLogID(1,2).Status = Failed to Generate]
				+ write log for change status
			2.KEEP Failed NotiID in #tmpInsertedNoti ***[From SettlementLogID(1,2).Status = Failed to Generate => NotificationID(9).Status = Failed to Generate]
			3.DEL Failed NotiID
		*/
		-- update tmpResultHist--
		;WITH CTE_ELog AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT *
					FROM #tmpResultHist AS rh
						LEFT JOIN #tmpNoti AS n ON rh.SettlementLogID = n.SettlementLogID
						LEFT JOIN #tmpNotiTarget AS ntgt ON rh.SettlementLogID = ntgt.SettlementLogID
						LEFT JOIN #tmpRemotingRef AS rf ON rh.SettlementLogID = rf.SettlementLogID
					WHERE rh.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpResultHist AS s
		)
		,CTE_SLog AS (
			SELECT GrpID
				,STRING_AGG(CONVERT(NVARCHAR(MAX),NotificationID),',') AS NotiIDs
			FROM #tmpInsertedNoti
			GROUP BY GrpID
		)
		,CTE_NotiSts AS (
			SELECT i.GrpID
				,MIN(CASE WHEN ISNULL(n.StatusID, -1) <> i.SuccessStatusID THEN 0
						ELSE 1 END) AS ValidSts
			FROM #tmpInsertedNoti AS i
				LEFT JOIN Notification AS n ON i.NotificationID = n.NotificationID
			GROUP BY i.GrpID
		)
		UPDATE rh
		SET rh.StatusID = (CASE WHEN ISNULL(ns.ValidSts,0) = 1 THEN @StsGenerated ELSE @StsGenFailed END)
			,rh.NotiLogBef = rh.NotiLogBef + (CASE WHEN ISNULL(ns.ValidSts,0) = 1 THEN 'Changed SettlementLogID Status from [Generating] to [Successfully Generated] - NotiIDs(' + ISNULL(sl.NotiIDs,'NULL') + ')'
							ELSE ' - All Info as JSON = ' + ISNULL(el.LTxt,'NULL') END) --error log write bellow
		FROM #tmpResultHist AS rh
			LEFT JOIN #tmpPrepareInsertNoti AS p ON rh.SettlementLogID = p.SettlementLogID
			LEFT JOIN CTE_NotiSts AS ns ON p.GrpID = ns.GrpID
			LEFT JOIN CTE_SLog AS sl ON p.GrpID = sl.GrpID
			LEFT JOIN CTE_ELog AS el ON rh.SettlementLogID = el.SettlementLogID
		
		--Keep Failed NotiID in #tmpInsertedNoti
		;WITH CTE_FailedNoti AS (
			SELECT n.NotificationID
			FROM Notification AS n WITH (NOLOCK)
				INNER JOIN #tmpInsertedNoti AS i ON n.NotificationID = i.NotificationID
			WHERE n.StatusID <> i.SuccessStatusID
			
			UNION ALL
			
			SELECT n.NotificationID
			FROM Notification AS n WITH (NOLOCK)
				INNER JOIN NotiMapping AS nm ON n.NotificationID = nm.NotificationID
				INNER JOIN #tmpResultHist AS rh ON nm.SettlementLogID = rh.SettlementLogID
			WHERE rh.StatusID = @StsGenFailed
		)
		DELETE i
		FROM #tmpInsertedNoti AS i
		WHERE i.NotificationID NOT IN (SELECT DISTINCT NotificationID FROM CTE_FailedNoti)
		
		--DEL Failed NotiID - #tmpInsertedNoti keep Failed NotiID
			--Notification
			--NotificationTarget
			--NotiMapping
			--NotificationExtra
		DELETE FROM Notification
		WHERE NotificationID IN (SELECT NotificationID FROM #tmpInsertedNoti)
		
		DELETE FROM NotificationTarget
		WHERE NotificationID IN (SELECT NotificationID FROM #tmpInsertedNoti)
		
		DELETE FROM NotiMapping
		WHERE NotificationID IN (SELECT NotificationID FROM #tmpInsertedNoti)
		
		DELETE FROM NotificationExtra
		WHERE NotificationID IN (SELECT NotificationID FROM #tmpInsertedNoti)
		
		--write log
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT NotificationID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Deleted Notification after consistency checking'
		FROM #tmpInsertedNoti AS i
		ORDER BY i.NotificationID
			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Insert new Notification - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	/****************************************************************************
		Final mark Failed if @ErrCode <> 0
	****************************************************************************/
	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
		UPDATE #tmpResultHist
		SET StatusID = @StsGenFailed
			,NotiLogBef = NotiLogBef + 'Changed SettlementLogID Status from [Generating] to [Failed to Generate] due to @ErrCode('+ ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL') + ')'
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT SettlementLogID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + ISNULL(NotiLogBef,'#tmpResultHist.NotiLogBef(NULL)')
		FROM #tmpResultHist
		ORDER BY SettlementLogID
		--update NotificationID Failed based on FAILED SettlementLogID
		UPDATE n
		SET n.StatusID = @StsGenFailed
		FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
			INNER JOIN NotiMapping AS nm ON n.NotificationID = nm.NotificationID
			INNER JOIN #tmpResultHist AS rh ON nm.SettlementLogID = rh.SettlementLogID
		
		--write log
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT n.NotificationID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Changed Notification StatusID = ' + ISNULL(CONVERT(VARCHAR,@StsGenFailed),'NULL') + ISNULL(' due to ' + @ErrMsg,'')
		FROM Notification AS n WITH (NOLOCK)
			INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
			INNER JOIN #tmpResultHist AS rh ON nm.SettlementLogID = rh.SettlementLogID
		ORDER BY n.NotificationID
	END
	
	--Final update SettlementResultHist
	UPDATE sh
	SET sh.StatusID = rh.StatusID
		,sh.LastModifiedTime = GETDATE()
	FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpResultHist AS rh ON sh.SettlementLogID = rh.SettlementLogID
	
	--write log
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT SettlementLogID
		,@LogActionID
		,@LogUserID
		,(CASE WHEN StatusID = @StsGenerated THEN @InfLogPrefix ELSE @ErrLogPrefix END) + ISNULL(rh.NotiLogBef,'SettlementLog NULL') + ISNULL(@ErrMsg,'')
	FROM #tmpResultHist AS rh
	ORDER BY SettlementLogID
	
	/****************************************************************************
	
		#7.Write final log
		
	****************************************************************************/
	IF @LogMode = 'Debug'
	BEGIN
		;WITH CTE_RemotingRef AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpRemotingRef AS t
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpRemotingRef AS s
			GROUP BY s.SettlementLogID
		)
		,CTE_ResultHist AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpResultHist AS t
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpResultHist AS s
			GROUP BY s.SettlementLogID
		)
		,CTE_Noti AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpNoti AS t
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpNoti AS s
			GROUP BY s.SettlementLogID
		)
		,CTE_NotiTarget AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpNotiTarget AS t
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpNotiTarget AS s
			GROUP BY s.SettlementLogID
		)
		,CTE_TemplateDetl AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpTemplateDetl AS t
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpTemplateDetl AS s
			GROUP BY s.SettlementLogID
		)
		,CTE_NotiInsList AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT *
					FROM #tmpPrepareInsertNoti AS t
						LEFT JOIN #tmpInsertedNoti AS i ON t.GrpID = i.GrpID
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpPrepareInsertNoti AS s
			GROUP BY s.SettlementLogID
		)
		,CTE_ResultInfo AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpResultInfo AS t
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpResultInfo AS s
			GROUP BY s.SettlementLogID
		)
		,CTE_AffectedResult AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
					SELECT t.*
					FROM #tmpAffectedResult AS t
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpAffectedResult AS s
			GROUP BY s.SettlementLogID
		)
		,CTE_Log AS (
			SELECT rh.SettlementLogID
				,STRING_AGG(CONVERT(NVARCHAR(MAX),(
					' ResultHist=(' + ISNULL(r.LTxt,'NULL') + ')'
					+ ' RemotingRef=(' + ISNULL(rf.LTxt,'NULL') + ')'
					+ ' Notification=(' + ISNULL(n.LTxt,'NULL') + ')'
					+ ' NotificationTarget=(' + ISNULL(nt.LTxt,'NULL') + ')'
					+ ' TemplateDetl=(' + ISNULL(tpd.LTxt,'NULL') + ')'
					+ ' NotiInsList=(' + ISNULL(i.LTxt,'NULL') + ')'
					+ ' ResultInfo=(' + ISNULL(ri.LTxt,'NULL') + ')'
					+ ' AffectedResult=(' + ISNULL(af.LTxt,'NULL') + ')'
				)),' / ') AS LogBef
			FROM #tmpResultHist AS rh
				LEFT JOIN CTE_ResultHist AS r ON rh.SettlementLogID = r.SettlementLogID
				LEFT JOIN CTE_RemotingRef AS rf ON rh.SettlementLogID = rf.SettlementLogID
				LEFT JOIN CTE_Noti AS n ON rh.SettlementLogID = n.SettlementLogID
				LEFT JOIN CTE_NotiTarget AS nt ON rh.SettlementLogID = nt.SettlementLogID
				LEFT JOIN CTE_TemplateDetl AS tpd ON rh.SettlementLogID = tpd.SettlementLogID
				LEFT JOIN CTE_NotiInsList AS i ON rh.SettlementLogID = i.SettlementLogID
				LEFT JOIN CTE_ResultInfo AS ri ON rh.SettlementLogID = ri.SettlementLogID
				LEFT JOIN CTE_AffectedResult AS af ON rh.SettlementLogID = af.SettlementLogID
			GROUP BY rh.SettlementLogID
		)
		UPDATE rh
		SET rh.NotiLogBef = rh.NotiLogBef + ISNULL(l.LogBef,'')
		FROM #tmpResultHist AS rh
			INNER JOIN CTE_Log AS l ON rh.SettlementLogID = l.SettlementLogID
		
		--write log
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT SettlementLogID
			,@LogActionID
			,@LogUserID
			,(CASE WHEN StatusID = @StsGenerated THEN @InfLogPrefix ELSE @ErrLogPrefix END) + ISNULL(rh.NotiLogBef,'SettlementLog NULL')
		FROM #tmpResultHist AS rh
		ORDER BY SettlementLogID
	END
	
	/****************************************************************************
	
		Change Process Status
		
	****************************************************************************/
	UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
	SET VValue = 'Done'
	WHERE VID = @ProcessID
		AND VValue = 'Running'
	
	DROP TABLE #tmpRemotingRef
	DROP TABLE #tmpResultHist
	DROP TABLE #tmpNoti
	DROP TABLE #tmpNotiTarget
	DROP TABLE #tmpTemplateDetl
	DROP TABLE #tmpPrepareInsertNoti
	DROP TABLE #tmpInsertedNoti
	DROP TABLE #tmpResultInfo
	DROP TABLE #tmpAffectedResult
END
