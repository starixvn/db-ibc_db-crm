/*<info serverAlias="DBCRM-MessageNotification" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_GenNotification
	@Environment VARCHAR(5)
	,@JSRemotingRef NVARCHAR(MAX)
AS
/*
	Created: 20231213@Roy
	Task: generate message
	DB: DBCRM.MessageNotification
	Revisions:
		20230515@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@Environment
			If UATMode = OFF
				+ @Environment = PRD => handle all data
				+ @Environment = UAT => return
			If UATMode = ON
				+ @Environment = PRD => handle REAL data
				+ @Environment = UAT => handle TEST data
		
		Input
			@JSRemotingRef NVARCHAR(MAX) = N'
				[
					{"SettlementLogIDs":"81","GroupName":"EventInfo","RefId1":"LeagueID","RefId2":"89623","RefValueEN":"Virtual Soccer Euro Cup","RefValueCH":"虛擬足球歐洲盃","RefValueCS":"虚拟足球欧洲杯"},
					{"SettlementLogIDs":"81,79,78","GroupName":"EventInfo","RefId1":"SportType","RefId2":"50","RefValueEN":"Cricket","RefValueCH":"板球","RefValueCS":"板球"},
					{"SettlementLogIDs":"81","GroupName":"EventInfo","RefId1":"TeamID","RefId2":"674489","RefValueEN":"England","RefValueCH":"英格兰","RefValueCS":"英格兰"},
					{"SettlementLogIDs":"81","GroupName":"EventInfo","RefId1":"TeamID","RefId2":"674497","RefValueEN":"Germany","RefValueCH":"德国","RefValueCS":"德国"}
					{"SettlementLogIDs":"52,64","GroupName":"EventInfo","RefId1":"TeamID","RefId2":"953783","RefValueEN":"Bangalore (V)","RefValueCH":"邦加羅爾虛擬隊","RefValueCS":"邦加罗尔虚拟队"}
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
			#3.Prepare data for to generate message
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
		,@LogActionID TINYINT
		,@StsGenerated TINYINT
		,@StsGenerating TINYINT
		,@StsGenFailed TINYINT
		,@StsNew TINYINT
		,@UATMode VARCHAR(5) = 'OFF'
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@ValidSettlementLogIDs VARCHAR(MAX)
		,@JSResource VARCHAR(MAX) = ''
		,@iLoop INT
		,@SabaLeagueGroup VARCHAR(500) = '42,74,108,113,122,151'
		,@Saba_en NVARCHAR(10) = N'Saba'
		,@Saba_ch NVARCHAR(10) = N'沙巴'
		,@Saba_cs NVARCHAR(10) = N'沙巴'
	
	/****************************************************************************
	
		#1.Load setting and create tmp Tables
		
	****************************************************************************/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @ProcessID = (
					CASE WHEN @Environment = 'PRD' THEN 5 --Process_GenerateNoti
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
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @UATMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --UATMode
	
	SELECT @ErrLogPrefix = 'Error - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @InfLogPrefix = 'Info - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @Environment = ISNULL(@Environment,'UAT')
	
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
		,Amended TINYINT DEFAULT 0
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
		-- ,ControlGrp TINYINT NOT NULL --0: OST / 1: 777 => No Need because not effect to content
		,RequiredParamID INT
		,RequiredParam VARCHAR(50)
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	CREATE CLUSTERED INDEX CIX_tmpTemplateDetl ON #tmpTemplateDetl (SettlementLogID, IsSabaFilter)
	
	CREATE TABLE #tmpNotiInsList (
		InternalID INT IDENTITY(1,1)
		,Grp INT
		,SettlementLogID INT
		,IsSabaFilter BIT
		,ControlGrp TINYINT
		,IsInsert BIT
	)
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiInsList ON #tmpNotiInsList (SettlementLogID, IsSabaFilter, ControlGrp)
	
	CREATE TABLE #tmpNotiInserted (
		NotificationID INT NOT NULL
		,InternalID INT
	)
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiMapping ON #tmpNotiInserted (NotificationID)
	
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
	
	/****************************************************************************
	
		#2.Get ValidSettleIDs and write log input params
		
	****************************************************************************/
	--write more info both PROD/UAT if enable UATMode
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Start Data loading with @UATMode = ' + @UATMode + ', @JSRemotingRef('+ISNULL(@JSRemotingRef,'NULL')+')'
	WHERE @UATMode = 'ON'
	
	EXEC MNC_ResultAmendment_GetSettlementLogIDs
		@Environment = @Environment
		,@JSRemotingRef = @JSRemotingRef
		,@ValidSettlementLogIDs = @ValidSettlementLogIDs OUTPUT
	
	/****************************************************************************
		#3.Prepare data for to generate message
			#tmpResultHist
			#tmpRemotingRef
			#tmpResultInfo
	****************************************************************************/
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
	
	--update Amended
	;WITH CTE_RefBettype AS (
		SELECT SettlementLogID
			,COUNT(DISTINCT RefBettypeID) AS Amended
		FROM #tmpResultInfo
		GROUP BY SettlementLogID
	)
	UPDATE rh
	SET rh.Amended = rb.Amended
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
		,(CASE WHEN (saba.SabaLG IS NOT NULL AND (ag.Site = '777777' OR s.IsChinaView = 1 OR s.SpecialPlatfrom > 0)) THEN 1
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
		LEFT JOIN CTE_SabaLG AS saba ON rh.LeagueGroupID = saba.SabaLG
	-- WHERE rh.SportType = 50 --Cricket
	
	/****************************************************<<<!IMPORTANT HARDCODE>>>***************************************************/
	;WITH CTE_Noti AS (
		SELECT DISTINCT rh.SettlementLogID
			,ntgt.IsSabaFilter
			,ntgt.ControlGrp
			,(CASE WHEN rh.ActionType = 1 AND rh.Amended = 1 THEN 3 --CAL to CAL, Amended=1
				WHEN rh.ActionType = 1 AND rh.Amended = 2 THEN 4 --CAL to CAL, Amended=2
				WHEN rh.ActionType = 1 AND rh.Amended > 2 THEN 5 --CAL to CAL, Amended = more than 2
				WHEN rh.ActionType IN (2,3) AND rh.Amended IN (1,2) THEN 1 --CAL to Refund / Refund to CAL, Amended = more than 2
				WHEN rh.ActionType IN (2,3) AND rh.Amended > 2 THEN 2 --CAL to Refund / Refund to CAL, Amended = more than 2
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
		SettlementLogID
		,IsSabaFilter
		,RequiredParamID
		,RequiredParam
	)
	SELECT DISTINCT n.SettlementLogID
		,n.IsSabaFilter
		-- ,n.ControlGrp --NOT effect to content
		,r.RequiredParamID
		,r.RequiredParam
	FROM #tmpNoti AS n
		INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID
		CROSS APPLY STRING_SPLIT(tp.RequiredParams, ',') AS rq
		INNER JOIN CTE_Param AS r WITH (NOLOCK) ON TRIM(rq.value) = r.RequiredParam
	
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
				,rfh.RefValueEN + (CASE WHEN rh.IsNeutral = 1 THEN ' (N)' ELSE '' END) AS HomeName_en
				,rfa.RefValueEN AS AwayName_en
				,(CASE WHEN tp.IsSabaFilter = 1 THEN REPLACE(rfl.RefValueEN,@Saba_en,'') --REMOVE 'SABA'
					ELSE rfl.RefValueEN END) AS LeagueName_en
				
				,rfh.RefValueCH + (CASE WHEN rh.IsNeutral = 1 THEN N' (中)' ELSE '' END) AS HomeName_ch
				,rfa.RefValueCH AS AwayName_ch
				,(CASE WHEN tp.IsSabaFilter = 1 THEN REPLACE(rfl.RefValueCH,@Saba_ch,'') --REMOVE 'SABA'
					ELSE rfl.RefValueCH END) AS LeagueName_ch
				
				,rfh.RefValueCS + (CASE WHEN rh.IsNeutral = 1 THEN N' (中)' ELSE '' END) AS HomeName_cs
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
				,MAX('"' + HomeName_en + ' -vs- ' + AwayName_en + '" [' + LeagueName_en + ' - ' + KO_DDMM + ']') AS Content_en
				,MAX('"' + HomeName_ch + ' -vs- ' + AwayName_ch + '" [' + LeagueName_ch + ' - ' + KO_DDMM + ']') AS Content_ch
				,MAX('"' + HomeName_cs + ' -vs- ' + AwayName_cs + '" [' + LeagueName_cs + ' - ' + KO_DDMM + ']') AS Content_cs
			FROM CTE_MatchInfoDetl
			GROUP BY SettlementLogID --GROUP BY to make sure only 1 Content foreach SettlementLogID/IsSabaFilter
				,IsSabaFilter
		)
		UPDATE tp
		SET tp.Content_en = m.Content_en
			,tp.Content_ch = m.Content_ch
			,tp.Content_cs = m.Content_cs
		FROM #tmpTemplateDetl AS tp
			INNER JOIN CTE_MatchInfo AS m ON tp.SettlementLogID = m.SettlementLogID AND tp.IsSabaFilter = m.IsSabaFilter
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
	
	/****************************************************************************
		#5.Handle for duplicate Content_en and Prepare for insert
	****************************************************************************/
	--get all valid Notification
	INSERT INTO #tmpNotiInsList (
		SettlementLogID
		,IsSabaFilter
		,ControlGrp
		-- ,InternalID INT IDENTITY(1,1)
	)
	SELECT DISTINCT n.SettlementLogID
		,n.IsSabaFilter
		,n.ControlGrp
	FROM #tmpResultHist AS rh
		INNER JOIN #tmpNoti AS n ON rh.SettlementLogID = n.SettlementLogID
		INNER JOIN #tmpNotiTarget AS ntgt ON n.SettlementLogID = ntgt.SettlementLogID AND n.IsSabaFilter = ntgt.IsSabaFilter AND n.ControlGrp = ntgt.ControlGrp
	WHERE rh.StatusID = @StsGenerating
		AND ISNULL(TRIM(n.Content_en),'') + ISNULL(TRIM(n.Content_ch),'') + ISNULL(TRIM(n.Content_cs),'') <> '' --Content is not BLANK
	ORDER BY n.SettlementLogID
		,n.IsSabaFilter
		,n.ControlGrp
	
	/*
		Remove duplicate Content_en by [SessionID] / [Content] / [user control group]
			+ [SessionID] 						= SessionID,MatchID
			+ [Content] = [SeqNo,IsSabaFilter] 	= Content_en
			+ [user control group] 				= ControlGrp
		
		=> GROUP BY SessionID, MatchID, Content_en, ControlGrp
	*/
	;WITH CTE_ContentGrp AS (
		SELECT rh.SessionID
			,rh.MatchID
			,n.Content_en
			,n.ControlGrp
			,ROW_NUMBER() OVER (ORDER BY rh.SessionID, rh.MatchID, n.Content_en, n.ControlGrp) AS Grp
		FROM #tmpResultHist AS rh
			INNER JOIN #tmpNoti AS n ON rh.SettlementLogID = n.SettlementLogID
			INNER JOIN #tmpNotiInsList AS il ON n.SettlementLogID = il.SettlementLogID AND n.IsSabaFilter = il.IsSabaFilter AND n.ControlGrp = il.ControlGrp
		GROUP BY rh.SessionID
			,rh.MatchID
			,n.Content_en
			,n.ControlGrp
	)
	,CTE_RemoveDupContent AS (
		SELECT n.SettlementLogID
			,n.IsSabaFilter
			,n.ControlGrp
			,cg.Grp
			,ROW_NUMBER() OVER (PARTITION BY cg.Grp ORDER BY n.SettlementLogID, n.IsSabaFilter, n.ControlGrp) AS RN --remove duplicate Content_en
		FROM CTE_ContentGrp AS cg
			INNER JOIN #tmpResultHist AS rh ON rh.SessionID = cg.SessionID AND rh.MatchID = cg.MatchID
			INNER JOIN #tmpNoti AS n ON n.Content_en = cg.Content_en AND n.ControlGrp = cg.ControlGrp
	)
	UPDATE il
	SET il.Grp = c.Grp
		,il.IsInsert = (CASE WHEN RN = 1 THEN 1 ELSE 0 END)
	FROM #tmpNotiInsList AS il
		LEFT JOIN CTE_RemoveDupContent AS c ON c.SettlementLogID = il.SettlementLogID AND c.IsSabaFilter = il.IsSabaFilter AND c.ControlGrp = il.ControlGrp
	
	/*
		Verify again with #tmpNotiInsList
			- In case SettlementLogID have 3 noti for Normal,Saba and 777
				+ 1 of those failed => SettlementLogID will be failed
	*/
	;WITH CTE_Check AS (
		SELECT rh.SettlementLogID
			,MIN(CASE WHEN i.SettlementLogID IS NULL THEN 0
					WHEN n.SettlementLogID IS NULL THEN 1
					WHEN ntgt.SettlementLogID IS NULL THEN 2
					ELSE 3 END) AS ValidSts --MUST EXISTS Noti / NotiTarget
		FROM #tmpResultHist AS rh
			LEFT JOIN #tmpNotiInsList AS i ON rh.SettlementLogID = i.SettlementLogID
			LEFT JOIN #tmpNoti AS n ON i.SettlementLogID = n.SettlementLogID AND i.IsSabaFilter = n.IsSabaFilter AND i.ControlGrp = n.ControlGrp
			LEFT JOIN #tmpNotiTarget AS ntgt ON i.SettlementLogID = ntgt.SettlementLogID AND i.IsSabaFilter = ntgt.IsSabaFilter AND i.ControlGrp = ntgt.ControlGrp
		WHERE rh.StatusID = @StsGenerating
		GROUP BY rh.SettlementLogID
	)
	UPDATE rh
	SET rh.StatusID = CASE WHEN ck.ValidSts = 3 THEN @StsGenerating ELSE @StsGenFailed END
		,rh.NotiLogBef = rh.NotiLogBef
						+ (CASE WHEN ck.ValidSts = 0 THEN 'Before INS Notification - NOT EIXSTS IN temporary insert list'
							WHEN ck.ValidSts = 1 THEN 'Before INS Notification - Missing S.T while creating Notification (ex: SettlementLogID have 3 Noti (Normal,Saba and 777) but have NO [Saba] in #tmpNoti)'
							WHEN ck.ValidSts = 2 THEN 'Before INS Notification - Missing S.T while creating NotificationTarget (have NO data in #tmpNotiTarget)'
							ELSE 'Ready for insert NotiMapping / Notification / NotificationTarget'
							END)
	FROM #tmpResultHist AS rh
		INNER JOIN CTE_Check AS ck ON rh.SettlementLogID = ck.SettlementLogID
	
	/****************************************************************************
		#6.Start to insert data
			Notification
			NotificationTarget
			NotificationExtra
			NotiMapping
	****************************************************************************/
	--insert Notification (foreach row)
	SELECT @iLoop = 1
	
	WHILE EXISTS(SELECT 1 FROM #tmpNotiInsList WHERE InternalID = @iLoop)
	BEGIN
		IF NOT EXISTS(SELECT 1 FROM #tmpNotiInsList WHERE IsInsert = 1 AND InternalID = @iLoop)
		BEGIN
			SET @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		INSERT INTO Notification (
			StatusID
			,NotificationType
			,Content_en
			,Content_ch
			,Content_cs
		)
		OUTPUT INSERTED.NotificationID
			,@iLoop
		INTO #tmpNotiInserted (
			NotificationID
			,InternalID
		) --Get Inserted
		SELECT rh.StatusID
			,1 AS NotificationType --Result Amendment to Msg
			,n.Content_en
			,n.Content_ch
			,n.Content_cs
		FROM #tmpNotiInsList AS il
			INNER JOIN #tmpNoti AS n ON il.SettlementLogID = n.SettlementLogID AND il.IsSabaFilter = n.IsSabaFilter AND il.ControlGrp = n.ControlGrp
			INNER JOIN #tmpResultHist AS rh ON il.SettlementLogID = rh.SettlementLogID
		WHERE rh.StatusID = @StsGenerating
			AND il.InternalID = @iLoop
			AND il.IsInsert = 1
			
		SET @iLoop = @iLoop + 1
	END
	
	/*
		Insert NotificationTarget
	*/
	;WITH CTE_AllTarget AS (
		SELECT s.Grp
			,ntgt.CustID AS TargetID
			,ntgt.TargetSite
			,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT tgt.TransID
						FROM #tmpNotiInsList AS t
							INNER JOIN #tmpNotiTarget AS tgt ON t.SettlementLogID = tgt.SettlementLogID AND t.IsSabaFilter = tgt.IsSabaFilter AND t.ControlGrp = tgt.ControlGrp
						WHERE t.Grp = s.Grp
							AND ntgt.TargetSite = tgt.TargetSite
							AND ntgt.CustID = tgt.CustID
						ORDER BY tgt.TransID
						FOR JSON AUTO
					)) AS TransIDs
		FROM #tmpNotiInsList AS s
			INNER JOIN #tmpNotiTarget AS ntgt ON s.SettlementLogID = ntgt.SettlementLogID AND s.IsSabaFilter = ntgt.IsSabaFilter AND s.ControlGrp = ntgt.ControlGrp
		GROUP BY s.Grp
			,ntgt.CustID
			,ntgt.TargetSite

		UNION ALL
		
		SELECT s.Grp
			,ntgt.AgentID AS TargetID
			,ntgt.TargetSite
			,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT tgt.TransID
						FROM #tmpNotiInsList AS t
							INNER JOIN #tmpNotiTarget AS tgt ON t.SettlementLogID = tgt.SettlementLogID AND t.IsSabaFilter = tgt.IsSabaFilter AND t.ControlGrp = tgt.ControlGrp
						WHERE t.Grp = s.Grp
							AND ntgt.TargetSite = tgt.TargetSite
							AND ntgt.AgentID = tgt.AgentID
						ORDER BY tgt.TransID
						FOR JSON AUTO
					)) AS TransIDs
		FROM #tmpNotiInsList AS s
			INNER JOIN #tmpNotiTarget AS ntgt ON s.SettlementLogID = ntgt.SettlementLogID AND s.IsSabaFilter = ntgt.IsSabaFilter AND s.ControlGrp = ntgt.ControlGrp
		GROUP BY s.Grp
			,ntgt.AgentID
			,ntgt.TargetSite
		
		UNION ALL
		
		SELECT s.Grp
			,ntgt.MasterID AS TargetID
			,ntgt.TargetSite
			,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT tgt.TransID
						FROM #tmpNotiInsList AS t
							INNER JOIN #tmpNotiTarget AS tgt ON t.SettlementLogID = tgt.SettlementLogID AND t.IsSabaFilter = tgt.IsSabaFilter AND t.ControlGrp = tgt.ControlGrp
						WHERE t.Grp = s.Grp
							AND ntgt.TargetSite = tgt.TargetSite
							AND ntgt.MasterID = tgt.MasterID
						ORDER BY tgt.TransID
						FOR JSON AUTO
					)) AS TransIDs
		FROM #tmpNotiInsList AS s
			INNER JOIN #tmpNotiTarget AS ntgt ON s.SettlementLogID = ntgt.SettlementLogID AND s.IsSabaFilter = ntgt.IsSabaFilter AND s.ControlGrp = ntgt.ControlGrp
		GROUP BY s.Grp
			,ntgt.MasterID
			,ntgt.TargetSite
		
		UNION ALL
		
		SELECT s.Grp
			,ntgt.SuperID AS TargetID
			,ntgt.TargetSite
			,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT tgt.TransID
						FROM #tmpNotiInsList AS t
							INNER JOIN #tmpNotiTarget AS tgt ON t.SettlementLogID = tgt.SettlementLogID AND t.IsSabaFilter = tgt.IsSabaFilter AND t.ControlGrp = tgt.ControlGrp
						WHERE t.Grp = s.Grp
							AND ntgt.TargetSite = tgt.TargetSite
							AND ntgt.SuperID = tgt.SuperID
						ORDER BY tgt.TransID
						FOR JSON AUTO
					)) AS TransIDs
		FROM #tmpNotiInsList AS s
			INNER JOIN #tmpNotiTarget AS ntgt ON s.SettlementLogID = ntgt.SettlementLogID AND s.IsSabaFilter = ntgt.IsSabaFilter AND s.ControlGrp = ntgt.ControlGrp
		GROUP BY s.Grp
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
		,@StsNew AS StatusID
		,tgt.TargetID
		,tgt.TargetSite
		,tgt.TransIDs
	FROM #tmpNotiInserted AS i
		INNER JOIN #tmpNotiInsList AS il ON i.InternalID = il.InternalID
		INNER JOIN CTE_AllTarget AS tgt ON il.Grp = tgt.Grp
		
	/*
		Insert NotiMapping
	*/
	INSERT INTO NotiMapping (
		SettlementLogID
		,NotificationID
	)
	SELECT DISTINCT ig.SettlementLogID
		,i.NotificationID
	FROM #tmpNotiInserted AS i
		INNER JOIN #tmpNotiInsList AS il ON i.InternalID = il.InternalID
		INNER JOIN #tmpNotiInsList AS ig ON ig.Grp = ig.Grp
	
	/*
		Insert NotificationExtra
	*/
	INSERT INTO NotificationExtra (
		NotificationID
		,EventDate
		,ExtraInfo
	)
	SELECT i.NotificationID
		,rh.EventDate
		,CONVERT(NVARCHAR(MAX),(
			SELECT DISTINCT t.MatchID
				,t.KOTime
				,t.IsNeutral
				,t.HomeID
				,rfh.RefValueEN AS HomeNameEN
				,rfh.RefValueCH AS HomeNameCH
				,rfh.RefValueCS AS HomeNameCS
				,t.AwayID
				,rfa.RefValueEN AS AwayNameEN
				,rfa.RefValueCH AS AwayNameCH
				,rfa.RefValueCS AS AwayNameCS
				,t.LeagueID
				,REPLACE(rfl.RefValueEN,@Saba_en,'') AS NoSabaLeagueNameEN
				,rfl.RefValueEN AS LeagueNameEN
				,REPLACE(rfl.RefValueCS,@Saba_cs,'') AS NoSabaLeagueNameCS
				,rfl.RefValueCS AS LeagueNameCS
				,REPLACE(rfl.RefValueCH,@Saba_ch,'') AS NoSabaLeagueNameCH
				,rfl.RefValueCH AS LeagueNameCH
			FROM #tmpResultHist AS t
				LEFT JOIN #tmpRemotingRef AS rfh ON t.SettlementLogID = rfh.SettlementLogID AND rfh.GroupName = 'EventInfo' AND rfh.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfh.RefId2) = rh.HomeID
				LEFT JOIN #tmpRemotingRef AS rfa ON t.SettlementLogID = rfa.SettlementLogID AND rfa.GroupName = 'EventInfo' AND rfa.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfa.RefId2) = rh.AwayID
				LEFT JOIN #tmpRemotingRef AS rfl ON t.SettlementLogID = rfl.SettlementLogID AND rfl.GroupName = 'EventInfo' AND rfl.RefId1 = 'LeagueID' AND TRY_CONVERT(INT,rfl.RefId2) = rh.LeagueID
			WHERE t.SettlementLogID = rh.SettlementLogID
			FOR JSON AUTO
		)) AS ExtraInfo
	FROM #tmpNotiInserted AS i
		INNER JOIN #tmpNotiInsList AS il ON i.InternalID = il.InternalID
		INNER JOIN #tmpResultHist AS rh ON il.SettlementLogID = rh.SettlementLogID
	
	/*
		Start to final update StatusID
	*/
	
	-- Check after insert NotiMapping / Notification / NotificationTarget
		-- + Update Notification StatusID = @StsNew
	;WITH CTE_Valid AS (
		SELECT DISTINCT n.NotificationID
		FROM Notification AS n
			INNER JOIN NotificationTarget AS nt ON n.NotificationID = nt.NotificationID
			INNER JOIN NotiMapping AS nm ON nt.NotificationID = nm.NotificationID
			INNER JOIN #tmpNotiInserted AS i ON nm.NotificationID = i.NotificationID
		WHERE n.StatusID = @StsGenerating
	)
	UPDATE n
	SET n.StatusID = @StsNew
	FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
		INNER JOIN CTE_Valid AS v ON n.NotificationID = v.NotificationID
	
	-- the rest, change to Failed
	UPDATE n
	SET n.StatusID = @StsGenFailed
	FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpNotiInserted AS i ON n.NotificationID = i.NotificationID
	WHERE n.StatusID <> @StsNew
	
	/*
		because [1 SettlementLogID have many NotificationID(normal, saba)] AND [1 NotificationID have many SettlementLogID(3 SiteDBs)]
			=> SettlementLogID vs NotificationID is Many:Many relationship
		
		if any NotificationID(*) Failed
			- update SettlementLogID(**) Failed based on NotificationID(*)
			- update NotificationID Failed based on SettlementLogID(**)
	*/
	IF EXISTS (
		SELECT 1
		FROM Notification AS n WITH (NOLOCK)
			INNER JOIN #tmpNotiInserted AS i ON n.NotificationID = i.NotificationID
		WHERE n.StatusID = @StsGenFailed
	)
	BEGIN
		--update SettlementLogID(**) Failed based on NotificationID(*)
		;WITH CTE_FailedSett AS (
			SELECT rh.SettlementLogID
				,STRING_AGG(CONVERT(VARCHAR(MAX),n.NotificationID),',') AS NotiIDs
			FROM Notification AS n WITH (NOLOCK)
				INNER JOIN #tmpNotiInserted AS i ON n.NotificationID = i.NotificationID
				INNER JOIN #tmpNotiInsList AS il ON i.InternalID = il.InternalID
				INNER JOIN #tmpNotiInsList AS ig ON il.Grp = ig.Grp
				INNER JOIN #tmpResultHist AS rh ON ig.SettlementLogID = rh.SettlementLogID
			WHERE n.StatusID = @StsGenFailed
			GROUP BY rh.SettlementLogID
		)
		UPDATE rh
		SET rh.StatusID = @StsGenFailed
		FROM #tmpResultHist AS rh
			INNER JOIN CTE_FailedSett AS f ON rh.SettlementLogID = f.SettlementLogID
		
		--update NotificationID Failed based on SettlementLogID(**)
		UPDATE n
		SET n.StatusID = @StsGenFailed
		FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
			INNER JOIN NotiMapping AS nm ON n.NotificationID = nm.NotificationID
			INNER JOIN #tmpResultHist AS rh ON nm.SettlementLogID = rh.SettlementLogID
		WHERE rh.StatusID = @StsGenFailed
			AND n.StatusID <> @StsGenFailed
		
		--update for loging
		;WITH CTE_FailedSett AS (
			SELECT rh.SettlementLogID
				,STRING_AGG(CONVERT(VARCHAR(MAX),n.NotificationID),',') AS NotiIDs
			FROM Notification AS n WITH (NOLOCK)
				INNER JOIN NotiMapping AS nm ON n.NotificationID = nm.NotificationID
				INNER JOIN #tmpResultHist AS rh ON nm.SettlementLogID = rh.SettlementLogID
			WHERE n.StatusID = @StsGenFailed
				OR rh.StatusID = @StsGenFailed
			GROUP BY rh.SettlementLogID
		)
		UPDATE rh
		SET rh.NotiLogBef = rh.NotiLogBef + '; After INS Notification - Failed due to Notification('+ f.NotiIDs +') Failed'
		FROM #tmpResultHist AS rh
			INNER JOIN CTE_FailedSett AS f ON rh.SettlementLogID = f.SettlementLogID
	END
	
	/*
		- change tmpResultHist.StatusID = [Generated] for Notification.StatusID = [New]
		- the rest of tmpResultHist.StatusID => [Failed]
		- change SettlementResultHist.StatusID = tmpResultHist.StatusID
	*/
	UPDATE rh
	SET rh.StatusID = @StsGenerated
	FROM #tmpResultHist AS rh
		INNER JOIN NotiMapping AS nm ON nm.SettlementLogID = rh.SettlementLogID
		INNER JOIN Notification AS n WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
	WHERE rh.StatusID = @StsGenerating
		AND n.StatusID = @StsNew
	
	UPDATE #tmpResultHist
	SET StatusID = @StsGenFailed
		,NotiLogBef = NotiLogBef + '; Final update tmpResultHist - Failed due to NO mapping between SettlementLogID vs NotificationID'
	WHERE StatusID = @StsGenerating
	
	UPDATE sh
	SET sh.StatusID = rh.StatusID
	FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpResultHist AS rh ON rh.SettlementLogID = sh.SettlementLogID
	
	--write log--
	;WITH CTE_Error AS (
		SELECT s.SettlementLogID
			,s.NotiLogBef
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
		WHERE s.StatusID = @StsGenFailed
	)
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT el.SettlementLogID
		,@LogActionID
		,@LogUserID
		,@ErrLogPrefix + 'Changed Status from [Generating] to [Failed to Generate] - ' + el.NotiLogBef + ' - All Info as JSON = ' + ISNULL(el.LTxt,'NULL')
	FROM CTE_Error AS el
	ORDER BY el.SettlementLogID
	
	/****************************************************************************
	
		#7.Write final log before / after gen message
		
	****************************************************************************/
	IF @UATMode = 'ON'
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
					FROM #tmpNotiInsList AS t
						LEFT JOIN #tmpNotiInserted AS i ON t.InternalID = i.InternalID
					WHERE t.SettlementLogID = s.SettlementLogID
					FOR JSON AUTO
				)) AS LTxt
			FROM #tmpNotiInsList AS s
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
			WHERE rh.StatusID = @StsGenerated
			GROUP BY rh.SettlementLogID
		)
		UPDATE rh
		SET rh.NotiLogBef = ISNULL(l.LogBef,'')
		FROM #tmpResultHist AS rh
			INNER JOIN CTE_Log AS l ON rh.SettlementLogID = l.SettlementLogID
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
	DROP TABLE #tmpNotiInsList
	DROP TABLE #tmpNotiInserted
	DROP TABLE #tmpResultInfo
	DROP TABLE #tmpAffectedResult
END
