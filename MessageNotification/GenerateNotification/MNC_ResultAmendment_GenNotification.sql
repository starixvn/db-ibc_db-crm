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
					{"SettlementLogIDs":"4271","NotificationIDs":null,"GroupName":"EventInfo","RefId1":"LeagueID","RefId2":"90084","RefValueEN":"SABA Cricket Ten10 Virtual Tri Nations Game 6 - Over 1 Total Runs","RefValueCH":"沙巴虛擬板球Ten10 三國賽 (第六場) - 第一輪跑位總得分","RefValueCS":"沙巴虚拟板球Ten10 三国赛 (第六场) - 第一轮跑位总得分"}
					,{"SettlementLogIDs":"4271","NotificationIDs":null,"GroupName":"EventInfo","RefId1":"SportType","RefId2":"50","RefValueEN":"Cricket","RefValueCH":"板球","RefValueCS":"板球"}
					,{"SettlementLogIDs":"4271","NotificationIDs":null,"GroupName":"EventInfo","RefId1":"TeamID","RefId2":"874483","RefValueEN":"Farhan Javaid","RefValueCH":"Farhan Javaid","RefValueCS":"Farhan Javaid"}
					,{"SettlementLogIDs":"4271","NotificationIDs":null,"GroupName":"EventInfo","RefId1":"TeamID","RefId2":"874484","RefValueEN":"Raza Fraz","RefValueCH":"Raza Fraz","RefValueCS":"Raza Fraz"}
					,{"SettlementLogIDs":"4271","NotificationIDs":null,"GroupName":"RefResource","RefId1":"ResourceCricket","RefId2":"00","RefValueEN":"Match Winner","RefValueCH":"比賽獲勝者","RefValueCS":"比赛获胜者"}
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
		,@UATMode BIT = 0
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@ValidSettlementLogIDs VARCHAR(MAX)
		,@JSResource NVARCHAR(MAX) = ''
		,@iLoop INT
		,@LogMode VARCHAR(500)
		,@SabaLeagueGroup VARCHAR(500) = '42,74,108,113,122,151,215'
		,@Sites777 VARCHAR(500) = ''
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
		CASE WHEN @Environment = 'LIVE' THEN 5 --Process_GenerateMsgNoti
			ELSE 8 END --ProcessUAT_GenerateMsgNoti
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
	
	SELECT @Sites777 = ISNULL(VValue,'')
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 16 --Separate Noti by Site
	
	SELECT @LogMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
	
	SELECT @UATMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --UATMode
	
	SELECT @ErrLogPrefix = 'Error - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @InfLogPrefix = 'Info - ' + ISNULL(@Environment,'Environment NULL') + ' - '
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
	IF @UATMode = 0 AND @Environment = 'UAT' --no action (RETURN)
	BEGIN
		SELECT @ErrCode = 50001 --user-defined error code
			,@ErrMsg = 'NO Action for UATMode = OFF AND Environment = UAT'
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + '[Generate Msg Noti process - Gen] - NO Action for UATMode = OFF AND Environment = UAT')
		
		RETURN
	END
	
	CREATE TABLE #tmpRemotingRef (
		GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
		,RefValueEN NVARCHAR(500)
		,RefValueCH NVARCHAR(500)
		,RefValueCS NVARCHAR(500)
	)
	
	CREATE TABLE #tmpResultHist (
		NotiTempID INT
		,SettlementLogID INT NOT NULL
		,StatusID TINYINT NOT NULL
		,NotiLog NVARCHAR(MAX) DEFAULT ''
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
	
	CREATE TABLE #tmpResultInfo (
		NotiTempID INT
		,SettlementLogID INT
		,AmendInfo VARCHAR(50)
		,ResourceID VARCHAR(50)
		,RefBettypeID VARCHAR(50)
		,HomeValue VARCHAR(50)
		,AwayValue VARCHAR(50)
		,OtherInfo VARCHAR(200)
		,TeamIDs VARCHAR(200)
		,G VARCHAR(50)
		,M VARCHAR(50)
		,X VARCHAR(50)
		,Y VARCHAR(50)
	)
	
	CREATE TABLE #tmpAffectedResult (
		NotiTempID INT
		,ResourceID VARCHAR(50)
		,OtherInfo VARCHAR(50)
		,G VARCHAR(50)
		,M VARCHAR(50)
		,X VARCHAR(50)
		,Y VARCHAR(50)
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

	/*
		Create Notification
			Group by 
				SessionID / ActionType => SettlementLogID
				/ IsNoneSaba
				/ user control group (OST or 777)
		
		1 SettlementLogID in #tmpResultHist
		can be 3 rows in #tmpStagingNoti
			- IsNoneSaba = 0: Normal
			- IsNoneSaba = 1: Saba
				+ User Control Group (OST)
				+ User Control Group (777)
	*/
	CREATE TABLE #tmpStagingNoti (
		NotiTempID INT NOT NULL
		,IsNoneSaba TINYINT NOT NULL --0: Normal / 1: Saba
		,TemplateID INT NOT NULL
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	
	/*
		1 NotificationID (SettlementLogID / IsNoneSaba / ControlGrp)
		have at least 4 rows in NotificationTarget for (CustID / recommend / mrecommend / srecommend)
	*/
	CREATE TABLE #tmpStagingTarget (
		NotiTempID INT NOT NULL
		,IsNoneSaba TINYINT NOT NULL --0: Normal / 1: Saba
		,ControlGrp TINYINT NOT NULL --0: OST / 1: 777
		,TargetSite NVARCHAR(30)
		,CustID INT
		,AgentID INT
		,MasterID INT
		,SuperID INT
		,TransID BIGINT
	)
	
	CREATE TABLE #tmpTemplateDetl (
		NotiTempID INT NOT NULL
		,IsNoneSaba TINYINT NOT NULL --0: Normal / 1: Saba
		,RequiredParamID INT
		,RequiredParam VARCHAR(50)
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
	)
	
	CREATE TABLE #tmpNotiByContent (
		NotiByContID INT
		,NotiTempID INT
		,IsNoneSaba TINYINT
		,ControlGrp TINYINT
	)
	
	CREATE TABLE #tmpInsertedNoti (
		NotificationID INT NOT NULL
		,NotiByContID INT
		,SuccessStatusID TINYINT --based on SystemSetting.VName = 'IgnoreReviewContentBySport'
	)
	
	CREATE TABLE #tmpFailedNoti (
		NotificationID INT NOT NULL PRIMARY KEY
	)
	
	--write log for LogMode = Debug
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Debug - Start [Generate Msg Noti process - Gen]'
						+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
						+ ' - @UATMode(' + ISNULL(CONVERT(VARCHAR,@UATMode),'NULL') + ')'
						+ ' - @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')')
	WHERE @LogMode = 'Debug'
	/****************************************************************************
	
		#2.Get ValidSettleIDs and write log input params
		
	****************************************************************************/	
	EXEC MNC_ResultAmendment_GetSettlementLogIDs
		@Environment = @Environment
		,@JSRemotingRef = @JSRemotingRef
		,@ValidSettlementLogIDs = @ValidSettlementLogIDs OUTPUT
	
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Start [Generate Msg Noti process - Gen]'
						+ ' - @ValidSettlementLogIDs(' + ISNULL(@ValidSettlementLogIDs,'NULL') + ')')
	
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
			,COALESCE(m.GlobalShowTime, m14.GlobalShowTime, m.kickofftime, m14.kickofftime) AS KOTime --prefer GlobalShowTime
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
			-- AND ISNULL(m.MatchID, m14.MatchID) IS NOT NULL
		CREATE CLUSTERED INDEX CIX_tmpResultHist ON #tmpResultHist (SettlementLogID)
		
		INSERT INTO #tmpRemotingRef (
			GroupName
			,RefId1
			,RefId2
			,RefValueEN
			,RefValueCH
			,RefValueCS
		)
		SELECT DISTINCT rf.GroupName
			,rf.RefId1
			,rf.RefId2
			,rf.RefValueEN
			,rf.RefValueCH
			,rf.RefValueCS
		FROM OPENJSON(@JSRemotingRef) WITH (
				SettlementLogIDs VARCHAR(MAX) '$.SettlementLogIDs'
				,GroupName VARCHAR(50) '$.GroupName'
				,RefId1 VARCHAR(50) '$.RefId1'
				,RefId2 VARCHAR(50) '$.RefId2'
				,RefValueEN NVARCHAR(500) '$.RefValueEN'
				,RefValueCH NVARCHAR(500) '$.RefValueCH'
				,RefValueCS NVARCHAR(500) '$.RefValueCS'
			) AS rf--OPENJSON case-sensitive
		CROSS APPLY STRING_SPLIT(rf.SettlementLogIDs, ',') AS SettID
		WHERE TRY_CONVERT(INT, SettID.value) IN ( SELECT SettlementLogID FROM #tmpResultHist )
		
		CREATE CLUSTERED INDEX CIX_tmpRemotingRef ON #tmpRemotingRef (GroupName, RefId1, RefId2)
		
		/*
			Parse data from ActualResult / WrongResult
				#tmpResultInfo
		*/
		EXEC MNC_ResultAmendment_JSParseResult
			@SettlementLogIDs = @ValidSettlementLogIDs
			,@ParseAmendInfo = 'ActualResult,WrongResult'
			,@ParseTo = 'RawData'
			,@OutJSResource = @JSResource OUTPUT
			,@ErrCode = @ErrCode OUTPUT --from SP params
			,@ErrMsg = @ErrMsg OUTPUT --from SP params
		
		;WITH CTE_DetailXML AS (
			SELECT rh.SettlementLogID
				,TRY_CONVERT(XML, bf.ExtraInfo_Before) AS ExtraXML
			FROM SettlementResultHistDetail AS bf WITH (NOLOCK)
				INNER JOIN #tmpResultHist AS rh ON bf.SettlementLogID = rh.SettlementLogID
					
			UNION ALL
					
			SELECT rh.SettlementLogID
				,TRY_CONVERT(XML, af.ExtraInfo_After) AS ExtraXML
			FROM SettlementResultHistDetail AS af WITH (NOLOCK)
				INNER JOIN #tmpResultHist AS rh ON af.SettlementLogID = rh.SettlementLogID

		)
		,CTE_ResourceID AS (
			SELECT DISTINCT SettlementLogID
				,TRIM(a.c.value('@Id', 'VARCHAR(50)')) AS ResourceID
			FROM CTE_DetailXML
				OUTER APPLY ExtraXML.nodes('root/r') a(c)
			WHERE ISNULL(TRIM(a.c.value('@Id', 'VARCHAR(50)')),'') <> ''
		)
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
			,M
			,X
			,Y
		)
		SELECT DISTINCT sr.SettlementLogID
			,sr.AmendInfo --ActualResult / WrongResult / ..
			,sr.ResourceID
			,sr.RefBettypeID
			,sr.HomeValue
			,sr.AwayValue
			,sr.OtherInfo
			,sr.TeamIDs
			,sr.G
			,sr.M
			,sr.X
			,sr.Y
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
				,M VARCHAR(50) '$.M'
				,X VARCHAR(50) '$.X'
				,Y VARCHAR(50) '$.Y'
		) AS sr--OPENJSON case-sensitive
			INNER JOIN CTE_ResourceID AS dr ON sr.SettlementLogID = dr.SettlementLogID AND sr.ResourceID = dr.ResourceID
		WHERE sr.RefBettypeID IS NOT NULL
			AND ISJSON(@JSResource) = 1
		
		CREATE CLUSTERED INDEX CIX_tmpResultInfo ON #tmpResultInfo (SettlementLogID, AmendInfo, ResourceID)
		
		--update NotiTempID / AmendedCnt
		;WITH CTE_RefBettype AS (
			SELECT 
				-- [SessionID, MatchID, SeqNo] UNIQUE
				rh.SessionID
				,rh.MatchID
				,rh.SeqNo
				-- ActionType (Make sure UNIQUE the same ActionType - Affect to TemplateID)
				,rh.ActionType
				,COUNT(DISTINCT ri.ResourceID) AS AmendedCnt
				,ROW_NUMBER() OVER (ORDER BY rh.SessionID ,rh.MatchID, rh.SeqNo, rh.ActionType) AS NotiTempID
			FROM #tmpResultHist AS rh
				INNER JOIN #tmpResultInfo AS ri ON rh.SettlementLogID = ri.SettlementLogID
			GROUP BY rh.SessionID
				,rh.MatchID
				,rh.SeqNo
				,rh.ActionType
		)
		UPDATE rh
		SET rh.AmendedCnt = rb.AmendedCnt
			,rh.NotiTempID = rb.NotiTempID
		FROM #tmpResultHist AS rh
			INNER JOIN CTE_RefBettype AS rb
				ON rh.SessionID = rb.SessionID
					AND rh.MatchID = rb.MatchID
					AND rh.SeqNo = rb.SeqNo
					AND rh.ActionType = rb.ActionType
		
		--update tmpResultInfo NotiTempID
		UPDATE ri
		SET ri.NotiTempID = rh.NotiTempID
		FROM #tmpResultInfo AS ri
			INNER JOIN #tmpResultHist AS rh ON rh.SettlementLogID = ri.SettlementLogID
		/*
			***************************************************<<<!IMPORTANT HARDCODE>>>***************************************************
			Mapping SettlementLogID vs TemplateID, output tables:
				#tmpStagingTarget (SettlementResultHistDetail with SMA + CustID)
				#tmpStagingNoti (UNIQUE SettlementLogID, IsNoneSaba, ControlGrp, TemplateID)
				#tmpTemplateDetl
		*/
		/*----------#tmpNotiTarget------------
			IsNoneSaba = Saba
				+ LeagueGroupID IN (@SabaLeagueGroup)
				+ TargetSite belong to special sites
		*/
		;WITH CTE_SabaLG AS (
			SELECT TRY_CONVERT(INT,value) AS SabaLG
			FROM STRING_SPLIT(@SabaLeagueGroup, ',')
		)
		INSERT INTO #tmpStagingTarget (
			NotiTempID
			,IsNoneSaba
			,ControlGrp
			,TargetSite
			,CustID
			,AgentID
			,MasterID
			,SuperID
			,TransID
		)
		SELECT DISTINCT rh.NotiTempID
			,(CASE WHEN (saba.value IS NOT NULL AND (sep.value IS NOT NULL OR s.IsChinaView = 1 OR s.SpecialPlatfrom > 0)) THEN 1
				ELSE 0 END) AS IsNoneSaba --0: Normal / 1: Saba
			,(CASE WHEN (sep.value IS NOT NULL) THEN 1 --configured in SytemSetting
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
			LEFT JOIN STRING_SPLIT(@Sites777, ',') AS sep ON ag.Site = TRIM(sep.value)
		-- WHERE rh.SportType = 50 --Cricket
		
		CREATE CLUSTERED INDEX CIX_tmpStagingTarget ON #tmpStagingTarget (NotiTempID, IsNoneSaba, ControlGrp)
		
		/****************************************************<<<!IMPORTANT HARDCODE>>>***************************************************/
		;WITH CTE_Noti AS (
			SELECT DISTINCT ntgt.NotiTempID
				,ntgt.IsNoneSaba
				,(CASE WHEN rh.ActionType = 1 AND rh.AmendedCnt = 1 THEN 3 --CAL to CAL, AmendedCnt=1
					WHEN rh.ActionType = 1 AND rh.AmendedCnt = 2 THEN 4 --CAL to CAL, AmendedCnt=2
					WHEN rh.ActionType = 1 AND rh.AmendedCnt > 2 THEN 5 --CAL to CAL, AmendedCnt = more than 2
					WHEN rh.ActionType IN (2,3) AND rh.AmendedCnt IN (1,2) THEN 1 --CAL to Refund / Refund to CAL, AmendedCnt = more than 2
					WHEN rh.ActionType IN (2,3) AND rh.AmendedCnt > 2 THEN 2 --CAL to Refund / Refund to CAL, AmendedCnt = more than 2
				END) AS TemplateID
			FROM #tmpResultHist AS rh
				INNER JOIN #tmpStagingTarget AS ntgt ON rh.NotiTempID = ntgt.NotiTempID
		)
		INSERT INTO #tmpStagingNoti (
			NotiTempID
			,IsNoneSaba
			,TemplateID
			,Content_en
			,Content_ch
			,Content_cs
		)
		SELECT DISTINCT n.NotiTempID
			,n.IsNoneSaba
			,n.TemplateID
			,tp.Content_en
			,tp.Content_ch
			,tp.Content_cs
		FROM CTE_Noti AS n
			INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID
		
		CREATE UNIQUE CLUSTERED INDEX CIX_tmpStagingNoti ON #tmpStagingNoti (NotiTempID, IsNoneSaba)
		
		----------#tmpTemplateDetl-------------
		INSERT INTO #tmpTemplateDetl (
			NotiTempID
			,IsNoneSaba
			-- ,ControlGrp --NOT Affect to content
			,RequiredParam
		)
		SELECT DISTINCT n.NotiTempID
			,nt.IsNoneSaba
			,TRIM(rq.value) AS RequiredParam
		FROM #tmpStagingNoti AS n
			INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON n.TemplateID = tp.TemplateID
			CROSS APPLY STRING_SPLIT(tp.RequiredParams, ',') AS rq
			INNER JOIN #tmpStagingTarget AS nt ON n.NotiTempID = nt.NotiTempID
		WHERE ISNULL(TRIM(rq.value),'') <> ''
		
		CREATE CLUSTERED INDEX CIX_tmpTemplateDetl ON #tmpTemplateDetl (NotiTempID, IsNoneSaba)
		
		--write log
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Debug - [Generate Msg Noti process - Gen] - Prepare data'
							+ ' - tmpResultHist('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpResultHist
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - tmpStagingTarget('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpStagingTarget
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - tmpStagingNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpStagingNoti
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
							+ ' - tmpResultInfo('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpResultInfo
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - tmpRemotingRef('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpRemotingRef
											FOR JSON PATH
										))
									),'NO ROW') + ')')
		WHERE @LogMode = 'Debug'
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Prepare data - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	/****************************************************************************
		#4.Start to Build message
		
		Build RequiredParam text of Template
			#tmpTemplateDetl
	****************************************************************************/
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpStagingNoti)
	BEGIN TRY
		/*
			----------{match_info}----------
			+ DON'T care ControlGrp
			+ IsNoneSaba = 0: Normal / 1: Saba
				=> handle for special sites - REMOVE 'SABA'
			=> Build param's value (for) GROUP BY NotiTempID, IsNoneSaba
		*/
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{match_info}')
		BEGIN
			;WITH CTE_MatchInfoDetl AS (
				SELECT DISTINCT tp.NotiTempID
					,tp.IsNoneSaba
					,rfh.RefValueEN + (CASE WHEN rh.IsNeutral = 1 THEN N' ' + @Neutral_en ELSE '' END) AS HomeName_en
					,rfa.RefValueEN AS AwayName_en
					,(CASE WHEN tp.IsNoneSaba = 1 THEN TRIM(REPLACE(REPLACE(rfl.RefValueEN,' ' + @Saba_en + ' ',' '),@Saba_en,'')) --REMOVE 'SABA'
						ELSE rfl.RefValueEN END) AS LeagueName_en
					
					,rfh.RefValueCH + (CASE WHEN rh.IsNeutral = 1 THEN N' ' + @Neutral_ch ELSE '' END) AS HomeName_ch
					,rfa.RefValueCH AS AwayName_ch
					,(CASE WHEN tp.IsNoneSaba = 1 THEN TRIM(REPLACE(REPLACE(rfl.RefValueCH,' ' + @Saba_ch + ' ',' '),@Saba_ch,'')) --REMOVE 'SABA'
						ELSE rfl.RefValueCH END) AS LeagueName_ch
					
					,rfh.RefValueCS + (CASE WHEN rh.IsNeutral = 1 THEN N' ' + @Neutral_cs ELSE '' END) AS HomeName_cs
					,rfa.RefValueCS AS AwayName_cs
					,(CASE WHEN tp.IsNoneSaba = 1 THEN TRIM(REPLACE(REPLACE(rfl.RefValueCS,' ' + @Saba_cs + ' ',' '),@Saba_cs,'')) --REMOVE 'SABA'
						ELSE rfl.RefValueCS END) AS LeagueName_cs
					
					,CONVERT(VARCHAR(5),rh.KOTime,103) AS KO_DDMM
				FROM #tmpTemplateDetl AS tp
					INNER JOIN #tmpResultHist AS rh ON tp.NotiTempID = rh.NotiTempID
					INNER JOIN #tmpRemotingRef AS rfh ON rfh.GroupName = 'EventInfo' AND rfh.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfh.RefId2) = rh.HomeID
					INNER JOIN #tmpRemotingRef AS rfa ON rfa.GroupName = 'EventInfo' AND rfa.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfa.RefId2) = rh.AwayID
					INNER JOIN #tmpRemotingRef AS rfl ON rfl.GroupName = 'EventInfo' AND rfl.RefId1 = 'LeagueID' AND TRY_CONVERT(INT,rfl.RefId2) = rh.LeagueID
				WHERE tp.RequiredParam = '{match_info}'
			)
			,CTE_MatchInfo AS (
				--Pattern: "@home_name -vs- @away_name" [@league_name - @ko_date]
				SELECT NotiTempID
					,IsNoneSaba
					,MAX('"' + HomeName_en + ' -vs- ' + AwayName_en + '" [' + LeagueName_en + ' - ' + KO_DDMM + ']') AS Content_en
					,MAX('"' + HomeName_ch + ' -vs- ' + AwayName_ch + '" [' + LeagueName_ch + ' - ' + KO_DDMM + ']') AS Content_ch
					,MAX('"' + HomeName_cs + ' -vs- ' + AwayName_cs + '" [' + LeagueName_cs + ' - ' + KO_DDMM + ']') AS Content_cs
				FROM CTE_MatchInfoDetl
				GROUP BY NotiTempID --GROUP BY to make sure only 1 Content foreach NotiTempID/IsNoneSaba
					,IsNoneSaba
			)
			UPDATE tp
			SET tp.Content_en = m.Content_en
				,tp.Content_ch = m.Content_ch
				,tp.Content_cs = m.Content_cs
			FROM #tmpTemplateDetl AS tp
				INNER JOIN CTE_MatchInfo AS m ON tp.NotiTempID = m.NotiTempID AND tp.IsNoneSaba = m.IsNoneSaba
			WHERE tp.RequiredParam = '{match_info}'
		END
		
		----------{sport_name}----------
		IF EXISTS (SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = '{sport_name}')
		BEGIN
			UPDATE tp
			SET tp.Content_en = rf.RefValueEN
				,tp.Content_ch = rf.RefValueCH
				,tp.Content_cs = rf.RefValueCS
			FROM #tmpTemplateDetl AS tp
				INNER JOIN #tmpResultHist AS rh ON tp.NotiTempID = rh.NotiTempID --1 NotiTempID only 1 SportType
				INNER JOIN #tmpRemotingRef AS rf ON rf.GroupName = 'EventInfo' AND rf.RefId1 = 'SportType' AND TRY_CONVERT(INT,rf.RefId2) = rh.SportType
			WHERE tp.RequiredParam = '{sport_name}'
		END
		
		/*
			*****Message Template may NOT {affected_result_name} but use it for: gen LAP, chatbot LIC,..*****
			+ DON'T care ControlGrp
				+ DON'T care IsNoneSaba
			=> Build param's value for (GROUP BY) NotiTempID
			
				step #1 - get Resource_en / Resource_ch / Resource_cs
				step #2 - Replace X / Y
					2.1 Replace G / M for GameSession IN (1,8) - match 2 inning
					2.2 Replace G / M for GameSession NOT IN (1,8) - match 1 inning only
				step #3 - If exists [OtherInfo] => put it after the Resource_en
		*/
		BEGIN
			--step #1 - get Resource_en / Resource_ch / Resource_cs
			INSERT INTO #tmpAffectedResult (
				NotiTempID
				,ResourceID
				,OtherInfo
				,G
				,M
				,X
				,Y
				,ResultName_en
				,ResultName_ch
				,ResultName_cs
			)
			SELECT DISTINCT tp.NotiTempID
				,ISNULL(atl.ResourceID, wrg.ResourceID) AS ResourceID
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.OtherInfo ELSE wrg.OtherInfo END AS OtherInfo
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.G ELSE wrg.G END AS G
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.M ELSE wrg.M END AS M
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.X ELSE wrg.X END AS X
				,CASE WHEN atl.RefBettypeID IS NOT NULL THEN atl.Y ELSE wrg.Y END AS Y
				,rf.RefValueEN AS ResultName_en
				,rf.RefValueCH AS ResultName_ch
				,rf.RefValueCS AS ResultName_cs
			FROM #tmpTemplateDetl AS tp
				LEFT JOIN #tmpResultInfo AS atl ON tp.NotiTempID = atl.NotiTempID AND atl.AmendInfo = 'ActualResult'
				LEFT JOIN #tmpResultInfo AS wrg ON tp.NotiTempID = wrg.NotiTempID AND wrg.AmendInfo = 'WrongResult'
				INNER JOIN #tmpRemotingRef AS rf ON rf.RefId2 = ISNULL(atl.RefBettypeID, wrg.RefBettypeID)
			WHERE ISNULL(atl.ResourceID, wrg.ResourceID) IS NOT NULL
				AND ISNULL(atl.RefBettypeID, wrg.RefBettypeID) IS NOT NULL
				AND rf.GroupName = 'RefResource'
				AND rf.RefId1 = 'ResourceCricket'
			
			CREATE CLUSTERED INDEX CIX_tmpAffectedResult ON #tmpAffectedResult (NotiTempID, ResourceID)
			
			--step #2 - Replace X / Y
			UPDATE #tmpAffectedResult
			SET ResultName_en = REPLACE(ResultName_en,'@X',X)
				,ResultName_ch = REPLACE(ResultName_ch,'@X',X)
				,ResultName_cs = REPLACE(ResultName_cs,'@X',X)
			WHERE ISNULL(CHARINDEX('@X',ResultName_en),0) > 0
				OR ISNULL(CHARINDEX('@X',ResultName_ch),0) > 0
				OR ISNULL(CHARINDEX('@X',ResultName_cs),0) > 0
			
			UPDATE #tmpAffectedResult
			SET ResultName_en = REPLACE(ResultName_en,'@Y',Y)
				,ResultName_ch = REPLACE(ResultName_ch,'@Y',Y)
				,ResultName_cs = REPLACE(ResultName_cs,'@Y',Y)
			WHERE ISNULL(CHARINDEX('@Y',ResultName_en),0) > 0
				OR ISNULL(CHARINDEX('@Y',ResultName_ch),0) > 0
				OR ISNULL(CHARINDEX('@Y',ResultName_cs),0) > 0
			
			--step #2 - 2.1 Replace G / M for GameSession IN (1,8) - match 2 inning
			;WITH CTE_G_Inns AS (
				SELECT DISTINCT af.NotiTempID
					,af.ResourceID
					,'G' + af.G AS rG --Handle case 1 inning only later
				FROM #tmpAffectedResult AS af
					INNER JOIN #tmpResultHist AS rh ON af.NotiTempID = rh.NotiTempID AND rh.GameSession IN (1,8)
				WHERE ISNULL(CHARINDEX('@G',af.ResultName_en),0) > 0
					OR ISNULL(CHARINDEX('@G',af.ResultName_ch),0) > 0
					OR ISNULL(CHARINDEX('@G',af.ResultName_cs),0) > 0
			)
			UPDATE af
			SET ResultName_en = REPLACE(af.ResultName_en,'@G',rf.RefValueEN)
				,ResultName_ch = REPLACE(af.ResultName_ch,'@G',rf.RefValueCH)
				,ResultName_cs = REPLACE(af.ResultName_cs,'@G',rf.RefValueCS)
			FROM #tmpAffectedResult AS af
				INNER JOIN CTE_G_Inns AS inn ON af.NotiTempID = inn.NotiTempID AND af.ResourceID = inn.ResourceID
				LEFT JOIN #tmpRemotingRef AS rf ON rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResourceCricket' AND rf.RefId2 = inn.rG
			
			;WITH CTE_M_Inns AS (
				SELECT DISTINCT af.NotiTempID
					,af.ResourceID
					,'M' + af.M AS rM --Handle case 1 inning only later
				FROM #tmpAffectedResult AS af
					INNER JOIN #tmpResultHist AS rh ON af.NotiTempID = rh.NotiTempID AND rh.GameSession IN (1,8)
				WHERE ISNULL(CHARINDEX('@M',af.ResultName_en),0) > 0
					OR ISNULL(CHARINDEX('@M',af.ResultName_ch),0) > 0
					OR ISNULL(CHARINDEX('@M',af.ResultName_cs),0) > 0
			)
			UPDATE af
			SET ResultName_en = REPLACE(af.ResultName_en,'@M',ISNULL(rf.RefValueEN,''))
				,ResultName_ch = REPLACE(af.ResultName_ch,'@M',ISNULL(rf.RefValueCH,''))
				,ResultName_cs = REPLACE(af.ResultName_cs,'@M',ISNULL(rf.RefValueCS,''))
			FROM #tmpAffectedResult AS af
				INNER JOIN CTE_M_Inns AS inn ON af.NotiTempID = inn.NotiTempID AND af.ResourceID = inn.ResourceID
				LEFT JOIN #tmpRemotingRef AS rf ON rf.GroupName = 'RefResource' AND rf.RefId1 = 'ResourceCricket' AND rf.RefId2 = inn.rM
			
			----step #2 - 2.2 Replace G / M for GameSession NOT IN (1,8) - match 1 inning only
			UPDATE #tmpAffectedResult
			SET ResultName_en = TRIM(REPLACE(REPLACE(ResultName_en,' @G ',' '),'@G',''))
				,ResultName_ch = TRIM(REPLACE(REPLACE(ResultName_ch,' @G ',' '),'@G',''))
				,ResultName_cs = TRIM(REPLACE(REPLACE(ResultName_cs,' @G ',' '),'@G',''))
			
			UPDATE #tmpAffectedResult
			SET ResultName_en = TRIM(REPLACE(REPLACE(ResultName_en,' @M ',' '),'@M',''))
				,ResultName_ch = TRIM(REPLACE(REPLACE(ResultName_ch,' @M ',' '),'@M',''))
				,ResultName_cs = TRIM(REPLACE(REPLACE(ResultName_cs,' @M ',' '),'@M',''))
			
			--step #3 - If exists [OtherInfo] => put it after the Resource_en
			;WITH CTE_OtherInfo AS (
				SELECT af.NotiTempID
					,af.ResourceID
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueEN),' & ') AS r_en
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueCH),' & ') AS r_ch
					,STRING_AGG(CONVERT(NVARCHAR(MAX),rf.RefValueCS),' & ') AS r_cs
				FROM #tmpAffectedResult AS af
					CROSS APPLY STRING_SPLIT(OtherInfo, ',') AS o
					INNER JOIN #tmpRemotingRef AS rf ON rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = o.value
				WHERE TRY_CONVERT(INT,o.value) IS NOT NULL
				GROUP BY af.NotiTempID
					,af.ResourceID
			)
			UPDATE af
			SET af.ResultName_en = af.ResultName_en + ' - ' + TRIM(o.r_en)
				,af.ResultName_ch = af.ResultName_ch + ' - ' + TRIM(o.r_ch)
				,af.ResultName_cs = af.ResultName_cs + ' - ' + TRIM(o.r_cs)
			FROM #tmpAffectedResult AS af
				INNER JOIN CTE_OtherInfo AS o ON af.NotiTempID = o.NotiTempID AND af.ResourceID = o.ResourceID
		END
		
		-- IF EXISTS {affected_result_name}
		;WITH CTE_Affected AS (
			SELECT NotiTempID
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(ResultName_en,'')),', ') AS ResultName_en
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(ResultName_ch,'')),', ') AS ResultName_ch
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(ResultName_cs,'')),', ') AS ResultName_cs
			FROM #tmpAffectedResult
			GROUP BY NotiTempID
		)
		UPDATE tp
		SET tp.Content_en = '"' + af.ResultName_en + '"'
			,tp.Content_ch = '"' + af.ResultName_ch  + '"'
			,tp.Content_cs = '"' + af.ResultName_cs  + '"'
		FROM #tmpTemplateDetl AS tp
			INNER JOIN CTE_Affected AS af ON tp.NotiTempID = af.NotiTempID
		WHERE tp.RequiredParam = '{affected_result_name}'
		
		/*
			*****Message Template may NOT {new_value} but use it for: gen LAP, chatbot LIC,..*****
			
			{new_value}
				+ DON'T care ControlGrp
				+ DON'T care IsNoneSaba
			=> Build param's value (for) GROUP BY NotiTempID
			
			Follow below rules in order
				Rule#1.If exists TeamIDs=""874484"" , don't care HomeValue - it's result (...result is "Ireland" instead of "Scotland"...)
				Rule#2.If HomeValue is number, it's result (...result is ""12-03"" instead of ""11-04""...)
				Rule#3.If HomeValue is NOT number, it's RefResource.RefId = 'ResultSettlement'"
				**Include Away below Home
		*/
		UPDATE af
		SET af.ActualValue_en = N'Refund'
			,af.ActualValue_ch = N'退款'
			,af.ActualValue_cs = N'退款'
		FROM #tmpAffectedResult AS af
			INNER JOIN #tmpResultHist AS rh ON rh.NotiTempID = af.NotiTempID
		WHERE rh.ActionType = 2 --CAL to Refund => WrongResult [have value] + ActualResult [blank]
		
		--Rule#1.If exists TeamIDs
		;WITH CTE_TeamID AS (
			SELECT DISTINCT atl.NotiTempID
				,atl.ResourceID
				,t.value AS TeamID
			FROM #tmpResultInfo AS atl
				OUTER APPLY STRING_SPLIT(atl.TeamIDs, ',') AS t
			WHERE atl.AmendInfo = 'ActualResult'
				AND TRY_CONVERT(INT,t.value) IS NOT NULL
		)
		,CTE_TeamName AS (
			SELECT atl.NotiTempID
				,atl.ResourceID
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(rf.RefValueEN,'')),', ') AS TeamName_en
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(rf.RefValueCH,'')),', ') AS TeamName_ch
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(rf.RefValueCS,'')),', ') AS TeamName_cs
			FROM CTE_TeamID AS atl
				INNER JOIN #tmpRemotingRef AS rf ON rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = atl.TeamID
			GROUP BY atl.NotiTempID
				,atl.ResourceID
		)
		UPDATE af
		SET af.ActualValue_en = t.TeamName_en
			,af.ActualValue_ch = t.TeamName_ch
			,af.ActualValue_cs = t.TeamName_cs
		FROM #tmpAffectedResult AS af
			INNER JOIN CTE_TeamName AS t ON af.NotiTempID = t.NotiTempID AND af.ResourceID = t.ResourceID
		WHERE af.ActualValue_en IS NULL --EXCLUDE above rules
		
		--Rule#2.If HomeValue is number
		/*
			some cases:
			1.<xml Home="01" Away="" TeamIDs="" OtherInfo="">
				=> Home = 01
				=> {new_value} = {1} => handled below code
			2.<xml Home="01" Away="02" TeamIDs="" OtherInfo="">
				=> Home = 01
				=> {new_value} = {1-2} => handled below code
			3.<xml Home="01" TeamIDs="123" OtherInfo="123,456">
				=> Home = 01 => position 1 of [OtherInfo="123,456"] => Home = "123" = [TeamIDs="123"]
				=> {new_value} = {team name of 123} => Rule#1 handled
			4.<xml Home="01" TeamIDs="" OtherInfo="123,456">
				=> Home = 01 => position 1 of [OtherInfo="123,456"] => Home = "123" BUT [TeamIDs=""]
				=> IGNORE case because very complex to handle (must check bettype, convert this case to Rule#1 template...)
		*/
		;WITH CTE_HomeNumber AS (
			SELECT DISTINCT atl.NotiTempID
				,atl.ResourceID
				,atl.HomeValue
				,atl.AwayValue
			FROM #tmpResultInfo AS atl
			WHERE atl.AmendInfo = 'ActualResult'
				AND ISNUMERIC(REPLACE(ISNULL(atl.HomeValue,''),',','')) = 1
		)
		UPDATE af
		SET af.ActualValue_en = atl.HomeValue + ISNULL('-' + atl.AwayValue,'')
			,af.ActualValue_ch = atl.HomeValue + ISNULL('-' + atl.AwayValue,'')
			,af.ActualValue_cs = atl.HomeValue + ISNULL('-' + atl.AwayValue,'')
		FROM #tmpAffectedResult AS af
			INNER JOIN CTE_HomeNumber AS atl ON af.NotiTempID = atl.NotiTempID AND af.ResourceID = atl.ResourceID
		WHERE af.ActualValue_en IS NULL --EXCLUDE above rules
		
		--Rule#3.If HomeValue is NOT number
		;WITH CTE_HomeNotNumber AS (
			SELECT DISTINCT atl.NotiTempID
				,atl.ResourceID
				,atl.HomeValue
				,atl.AwayValue
			FROM #tmpResultInfo AS atl
			WHERE atl.AmendInfo = 'ActualResult'
				AND ISNUMERIC(REPLACE(ISNULL(atl.HomeValue,''),',','')) = 0
		)
		UPDATE af
		SET af.ActualValue_en = rfh.RefValueEN + ISNULL('-' + rfa.RefValueEN,'')
			,af.ActualValue_ch = rfh.RefValueCH + ISNULL('-' + rfa.RefValueCH,'')
			,af.ActualValue_cs = rfh.RefValueCS + ISNULL('-' + rfa.RefValueCS,'')
		FROM #tmpAffectedResult AS af
			INNER JOIN CTE_HomeNotNumber AS atl ON af.NotiTempID = atl.NotiTempID AND af.ResourceID = atl.ResourceID
			INNER JOIN #tmpRemotingRef AS rfh ON rfh.GroupName = 'RefResource' AND rfh.RefId1 = 'ResultSettlement' AND rfh.RefId2 = atl.HomeValue
			LEFT JOIN #tmpRemotingRef AS rfa ON rfa.GroupName = 'RefResource' AND rfa.RefId1 = 'ResultSettlement' AND rfa.RefId2 = atl.AwayValue
		WHERE af.ActualValue_en IS NULL --EXCLUDE above rules
		
		--Rule#final.the rest, value of HomeValue
		;WITH CTE_Rest AS (
			SELECT DISTINCT atl.NotiTempID
				,atl.ResourceID
				,atl.HomeValue
				,atl.AwayValue
			FROM #tmpResultInfo AS atl
			WHERE atl.AmendInfo = 'ActualResult'
		)
		UPDATE af
		SET af.ActualValue_en = atl.HomeValue + ISNULL('-' + atl.AwayValue,'')
			,af.ActualValue_ch = atl.HomeValue + ISNULL('-' + atl.AwayValue,'')
			,af.ActualValue_cs = atl.HomeValue + ISNULL('-' + atl.AwayValue,'')
		FROM #tmpAffectedResult AS af
			INNER JOIN #tmpResultInfo AS atl ON af.NotiTempID = atl.NotiTempID AND af.ResourceID = atl.ResourceID
		WHERE af.ActualValue_en IS NULL --EXCLUDE above rules
		
		-- IF EXISTS {new_value}
		UPDATE tp
		SET tp.Content_en = atl.ActualValue_en
			,tp.Content_ch = atl.ActualValue_ch
			,tp.Content_cs = atl.ActualValue_cs
		FROM #tmpTemplateDetl AS tp
			INNER JOIN #tmpAffectedResult AS atl ON tp.NotiTempID = atl.NotiTempID
		WHERE tp.RequiredParam = '{new_value}'
		
		/*
			*****Message Template may NOT {new_value} but use it for: gen LAP, chatbot LIC,..*****
			
			{old_value}
				+ DON'T care ControlGrp
				+ DON'T care IsNoneSaba
			=> Build param's value (for) GROUP BY NotiTempID
			
			Follow below rules in order
				Rule#1.If exists TeamIDs=""874484"" , don't care HomeValue - it's result (...result is "Ireland" instead of "Scotland"...)
				Rule#2.If HomeValue is number, it's result (...result is ""12,03"" instead of ""11,04""...)
				Rule#3.If HomeValue is NOT number, it's RefResource.RefId = 'ResultSettlement'"
		*/
		UPDATE af
		SET af.WrongValue_en = N'Refund'
			,af.WrongValue_ch = N'退款'
			,af.WrongValue_cs = N'退款'
		FROM #tmpAffectedResult AS af
			INNER JOIN #tmpResultHist AS rh ON rh.NotiTempID = af.NotiTempID
		WHERE rh.ActionType = 3 --Refund to CAL => WrongResult [blank] + ActualResult [have value]
		
		--Rule#1.If exists TeamIDs
		;WITH CTE_TeamID AS (
			SELECT DISTINCT wrg.NotiTempID
				,wrg.ResourceID
				,t.value AS TeamID
			FROM #tmpResultInfo AS wrg
				CROSS APPLY STRING_SPLIT(wrg.TeamIDs, ',') AS t
			WHERE wrg.AmendInfo = 'WrongResult'
				AND TRY_CONVERT(INT,t.value) IS NOT NULL
		)
		,CTE_TeamName AS (
			SELECT wrg.NotiTempID
				,wrg.ResourceID
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(rf.RefValueEN,'')),', ') AS TeamName_en
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(rf.RefValueCH,'')),', ') AS TeamName_ch
				,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(rf.RefValueCS,'')),', ') AS TeamName_cs
			FROM CTE_TeamID AS wrg
				INNER JOIN #tmpRemotingRef AS rf ON rf.GroupName = 'EventInfo' AND rf.RefId1 = 'TeamID' AND rf.RefId2 = wrg.TeamID
			GROUP BY wrg.NotiTempID
				,wrg.ResourceID
		)
		UPDATE af
		SET af.WrongValue_en = t.TeamName_en
			,af.WrongValue_ch = t.TeamName_ch
			,af.WrongValue_cs = t.TeamName_cs
		FROM #tmpAffectedResult AS af
			INNER JOIN CTE_TeamName AS t ON af.NotiTempID = t.NotiTempID AND af.ResourceID = t.ResourceID
		WHERE af.WrongValue_en IS NULL --EXCLUDE above rules
		
		--Rule#2.If HomeValue is number
		;WITH CTE_HomeNumber AS (
			SELECT DISTINCT wrg.NotiTempID
				,wrg.ResourceID
				,wrg.HomeValue
				,wrg.AwayValue
			FROM #tmpResultInfo AS wrg
			WHERE wrg.AmendInfo = 'WrongResult'
				AND ISNUMERIC(REPLACE(ISNULL(wrg.HomeValue,''),',','')) = 1
		)
		UPDATE af
		SET af.WrongValue_en = wrg.HomeValue + ISNULL('-' + wrg.AwayValue,'')
			,af.WrongValue_ch = wrg.HomeValue + ISNULL('-' + wrg.AwayValue,'')
			,af.WrongValue_cs = wrg.HomeValue + ISNULL('-' + wrg.AwayValue,'')
		FROM #tmpAffectedResult AS af
			INNER JOIN CTE_HomeNumber AS wrg ON af.NotiTempID = wrg.NotiTempID AND af.ResourceID = wrg.ResourceID
		WHERE af.WrongValue_en IS NULL --EXCLUDE above rules
		
		--Rule#3.If HomeValue is NOT number
		;WITH CTE_HomeNotNumber AS (
			SELECT DISTINCT wrg.NotiTempID
				,wrg.ResourceID
				,wrg.HomeValue
				,wrg.AwayValue
			FROM #tmpResultInfo AS wrg
			WHERE wrg.AmendInfo = 'WrongResult'
				AND ISNUMERIC(REPLACE(ISNULL(wrg.HomeValue,''),',','')) = 0
		)
		UPDATE af
		SET af.WrongValue_en = rfh.RefValueEN + ISNULL('-' + rfa.RefValueEN,'')
			,af.WrongValue_ch = rfh.RefValueCH + ISNULL('-' + rfa.RefValueCH,'')
			,af.WrongValue_cs = rfh.RefValueCS + ISNULL('-' + rfa.RefValueCS,'')
		FROM #tmpAffectedResult AS af
			INNER JOIN CTE_HomeNotNumber AS wrg ON af.NotiTempID = wrg.NotiTempID AND af.ResourceID = wrg.ResourceID
			INNER JOIN #tmpRemotingRef AS rfh ON rfh.GroupName = 'RefResource' AND rfh.RefId1 = 'ResultSettlement' AND rfh.RefId2 = wrg.HomeValue
			LEFT JOIN #tmpRemotingRef AS rfa ON rfa.GroupName = 'RefResource' AND rfa.RefId1 = 'ResultSettlement' AND rfa.RefId2 = wrg.AwayValue
		WHERE af.WrongValue_en IS NULL --EXCLUDE above rules
		
		--Rule#final.the rest, value of HomeValue
		;WITH CTE_Rest AS (
			SELECT DISTINCT wrg.NotiTempID
				,wrg.ResourceID
				,wrg.HomeValue
				,wrg.AwayValue
			FROM #tmpResultInfo AS wrg
			WHERE wrg.AmendInfo = 'WrongResult'
		)
		UPDATE af
		SET af.WrongValue_en = wrg.HomeValue + ISNULL('-' + wrg.AwayValue,'')
			,af.WrongValue_ch = wrg.HomeValue + ISNULL('-' + wrg.AwayValue,'')
			,af.WrongValue_cs = wrg.HomeValue + ISNULL('-' + wrg.AwayValue,'')
		FROM #tmpAffectedResult AS af
			INNER JOIN CTE_Rest AS wrg ON af.NotiTempID = wrg.NotiTempID AND af.ResourceID = wrg.ResourceID
		WHERE af.WrongValue_en IS NULL --EXCLUDE above rules
		
		-- IF EXISTS {old_value}
		UPDATE tp
		SET tp.Content_en = wrg.WrongValue_en
			,tp.Content_ch = wrg.WrongValue_ch
			,tp.Content_cs = wrg.WrongValue_cs
		FROM #tmpTemplateDetl AS tp
			INNER JOIN #tmpAffectedResult AS wrg ON tp.NotiTempID = wrg.NotiTempID
		WHERE tp.RequiredParam = '{old_value}'
		
		/*
			Build message content
				#tmpStagingNoti
			
			List of RequiredParam
				- {match_info}
					+ Build param's value (for) GROUP BY NotiTempID, IsNoneSaba
				- {new_value}
					+ Build param's value (for) GROUP BY NotiTempID
				- {old_value}
					+ Build param's value (for) GROUP BY NotiTempID
				- {sport_name}
					+ Build param's value (for) GROUP BY NotiTempID
				- {affected_result_name}
					+ Build param's value for (GROUP BY) NotiTempID
			=> Build message content (for) GROUP BY NotiTempID, IsNoneSaba
		*/
		DECLARE @iLoopParam VARCHAR(50)
		SELECT @iLoopParam = MIN(RequiredParam)
		FROM #tmpTemplateDetl
		
		WHILE EXISTS(SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = @iLoopParam)
		BEGIN
			--Start to replace RequiredParams
			UPDATE ms
			SET ms.Content_en = REPLACE(ms.Content_en,tpd.RequiredParam,tpd.Content_en)
				,ms.Content_ch = REPLACE(ms.Content_ch,tpd.RequiredParam,tpd.Content_ch)
				,ms.Content_cs = REPLACE(ms.Content_cs,tpd.RequiredParam,tpd.Content_cs)
			FROM #tmpStagingNoti AS ms
				INNER JOIN #tmpTemplateDetl AS tpd ON ms.NotiTempID = tpd.NotiTempID AND ms.IsNoneSaba = tpd.IsNoneSaba
			WHERE tpd.RequiredParam = @iLoopParam
			
			SET @iLoopParam = (SELECT MIN(RequiredParam) FROM #tmpTemplateDetl WHERE RequiredParam > @iLoopParam )
		END
		
		--write log
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + '[Generate Msg Noti process - Gen] - Build message'
							+ ' - tmpStagingNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpStagingNoti
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
									),'NO ROW') + ')')
		WHERE EXISTS (SELECT 1 FROM #tmpStagingNoti)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Build message content - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	/****************************************************************************
		#5.Handle for duplicate Content_en and Prepare for insert
	****************************************************************************/
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpStagingNoti)
	BEGIN TRY
		/*
			Remove duplicate Content_en by [SessionID] / [Content] / [user control group]
				+ [Session] 						= SessionID, MatchID
				+ [Content] = [SeqNo,IsNoneSaba] 	= Content_en
				+ [user control group] 				= ControlGrp
			
			=> GROUP BY SessionID, MatchID, Content_en, ControlGrp
		*/
		;WITH CTE_PrepareIns AS (
			SELECT rh.SessionID
				,rh.MatchID
				,n.Content_en
				,nt.ControlGrp
				,ROW_NUMBER() OVER (ORDER BY rh.SessionID, rh.MatchID, n.Content_en, nt.ControlGrp) AS NotiByContID --define [NotiByContID] of message content
			FROM #tmpResultHist AS rh
				INNER JOIN #tmpStagingNoti AS n ON rh.NotiTempID = n.NotiTempID
				INNER JOIN #tmpStagingTarget AS nt ON n.NotiTempID = nt.NotiTempID AND n.IsNoneSaba = nt.IsNoneSaba
			WHERE rh.StatusID = @StsGenerating
				AND ISNULL(TRIM(n.Content_en),'') + ISNULL(TRIM(n.Content_ch),'') + ISNULL(TRIM(n.Content_cs),'') <> '' --Content is not BLANK
			GROUP BY rh.SessionID
				,rh.MatchID
				,n.Content_en
				,nt.ControlGrp
		)
		INSERT INTO #tmpNotiByContent (
			NotiByContID
			,NotiTempID
			,IsNoneSaba
			,ControlGrp
		)
		--parse CTE_PrepareIns.NotiByContID => UNIQUE KEY OF #tmpNotiByContent
		SELECT DISTINCT i.NotiByContID
			,n.NotiTempID
			,n.IsNoneSaba
			,nt.ControlGrp
		FROM CTE_PrepareIns AS i
			INNER JOIN #tmpResultHist AS rh ON rh.SessionID = i.SessionID AND rh.MatchID = i.MatchID
			INNER JOIN #tmpStagingNoti AS n ON n.Content_en = i.Content_en AND n.NotiTempID = rh.NotiTempID
			INNER JOIN #tmpStagingTarget AS nt ON n.NotiTempID = nt.NotiTempID AND n.IsNoneSaba = nt.IsNoneSaba AND i.ControlGrp = nt.ControlGrp
		
		CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiByContent ON #tmpNotiByContent (NotiTempID, IsNoneSaba, ControlGrp)
		
		/*
			Verify #tmpResultHist again before insert (with #tmpNotiByContent)
			- In case #tmpResultHist.SettlementLogID NOT EXISTS #tmpNotiByContent
				=> that mean S.T wrong while creating Notification
					=> get related failure SettlementLogID by SessionID, MatchID
		*/
		;WITH CTE_Invalid_Content AS (
			SELECT DISTINCT rh.SettlementLogID
				,rh.SessionID
				,rh.MatchID
				,'S.T wrong while creating Notification Content (NOT EXITS in Valid Content)'
					+ ' - SessionID(' + ISNULL(rh.SessionID,'NULL') + ') - MatchID(' + ISNULL(CONVERT(VARCHAR,rh.MatchID),'NULL') + ')' AS lTxt
			FROM #tmpResultHist AS rh
				LEFT JOIN #tmpNotiByContent AS i ON rh.NotiTempID = i.NotiTempID
			WHERE i.NotiTempID IS NULL
		)
		,CTE_Relate_Of_Invalid_Content AS (
			SELECT DISTINCT rh.SettlementLogID
				,'Failed due to relating with SessionID(' + ISNULL(rh.SessionID,'NULL') + ') - MatchID(' + ISNULL(CONVERT(VARCHAR,rh.MatchID),'NULL') + ')' AS lTxt
			FROM #tmpResultHist AS rh
				INNER JOIN CTE_Invalid_Content AS inv ON rh.SessionID = inv.SessionID AND rh.MatchID = inv.MatchID
			WHERE rh.SettlementLogID <> inv.SettlementLogID
		)
		UPDATE rh
		SET rh.StatusID = @StsGenFailed
			,rh.NotiLog = rh.NotiLog + ISNULL(inv1.lTxt,inv2.lTxt)
		FROM #tmpResultHist AS rh
			LEFT JOIN CTE_Invalid_Content AS inv1 ON rh.SettlementLogID = inv1.SettlementLogID
			LEFT JOIN CTE_Relate_Of_Invalid_Content AS inv2 ON rh.SettlementLogID = inv2.SettlementLogID
		WHERE ISNULL(inv1.SettlementLogID,inv2.SettlementLogID) IS NOT NULL
		
		--------------DELETE invalid tmpNotiByContent--------------
		DELETE n
		FROM #tmpNotiByContent AS n
			INNER JOIN #tmpResultHist AS rh ON rh.NotiTempID = n.NotiTempID
		WHERE rh.StatusID = @StsGenFailed
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Handle duplicate Content - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	--write log
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + '[Generate Msg Noti process - Gen] - Build message & handle duplicate content compelted'
						+ ' - tmpNotiByContent('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpNotiByContent
										FOR JSON PATH
									))
								),'NO ROW') + ')'
						+ ' - Invalid tmpResultHist('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpResultHist
										WHERE StatusID = @StsGenFailed
										FOR JSON PATH
									))
								),'NO ROW') + ')'
						+ ' - tmpStagingTarget('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpStagingTarget
										FOR JSON PATH
									))
								),'NO ROW') + ')'
						+ ' - tmpStagingNoti('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpStagingNoti
										FOR JSON PATH
									))
								),'NO ROW') + ')')
	/****************************************************************************
		#6.Start to insert data
			Notification
			NotificationTarget
			NotificationExtra
			NotiMapping
	****************************************************************************/
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpNotiByContent)
	BEGIN TRY
		--insert Notification by NotiByContID (foreach row) to get [IDENTITY NotificationID] + [NotiByContID]
		SELECT @iLoop = MIN(NotiByContID)
		FROM #tmpNotiByContent
		
		WHILE EXISTS(SELECT 1 FROM #tmpNotiByContent WHERE NotiByContID = @iLoop)
		BEGIN
			;WITH CTE_InsertNoti AS (
				SELECT TOP 1 NotiTempID --only insert 1 Content for group of the same message content
					,IsNoneSaba
					,ControlGrp
				FROM #tmpNotiByContent
				WHERE NotiByContID = @iLoop
			)
			INSERT INTO Notification (
				StatusID
				,NotificationType
				,Content_en
				,Content_ch
				,Content_cs
			)
			OUTPUT INSERTED.NotificationID
				,@iLoop
			INTO #tmpInsertedNoti (
				NotificationID
				,NotiByContID
			) --Get Inserted
			SELECT DISTINCT rh.StatusID --Generating
				,1 AS NotificationType --Result Amendment to Msg
				,n.Content_en
				,n.Content_ch
				,n.Content_cs
			FROM CTE_InsertNoti AS il
				INNER JOIN #tmpStagingNoti AS n ON il.NotiTempID = n.NotiTempID AND il.IsNoneSaba = n.IsNoneSaba
				INNER JOIN #tmpResultHist AS rh ON il.NotiTempID = rh.NotiTempID
			WHERE rh.StatusID = @StsGenerating
			
			--increase for loop
			SET @iLoop = (SELECT MIN(NotiByContID) FROM #tmpNotiByContent WHERE NotiByContID > @iLoop)
		END
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT NotificationID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + '[Generate Msg Noti process - Gen] - Recent insertes MSG Notification with status = [Generating]')
		FROM #tmpInsertedNoti AS i
		WHERE @LogMode = 'Debug'
		ORDER BY i.NotificationID
		
		CREATE UNIQUE CLUSTERED INDEX CIX_tmpInsertedNoti ON #tmpInsertedNoti (NotificationID)
		
		---Dynamic StatusID by SystemSetting.VName = 'IgnoreReviewContentBySport'
		;WITH CTE_Noti_Status AS (
			SELECT DISTINCT i.NotificationID
				/*
					IF SportType EXISTS IN SystemSetting.VName = 'IgnoreReviewContentBySport'
						=> SuccessStatusID = 'Sending' => Ignore Review
					ELSE
						=> SuccessStatusID = 'New' => Need to review before push to Msg/MsgTarget
					
					***#tmpInsertedNoti.NotiByContID ONLY 1 MatchID => ONLY 1 SportType
				*/
				,(CASE WHEN cs.value IS NOT NULL THEN @StsSending
					ELSE @StsNew END) AS SuccessStatusID
			FROM #tmpInsertedNoti AS i
				INNER JOIN #tmpNotiByContent AS pr ON i.NotiByContID = pr.NotiByContID
				INNER JOIN #tmpResultHist AS rh ON pr.NotiTempID = rh.NotiTempID
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
			SELECT s.NotiByContID
				,ntgt.CustID AS TargetID
				,ntgt.TargetSite
				,CONVERT(NVARCHAR(MAX),(
							SELECT DISTINCT t.TransID
							FROM #tmpNotiByContent AS st
								INNER JOIN #tmpStagingTarget AS t ON st.NotiTempID = t.NotiTempID AND st.IsNoneSaba = t.IsNoneSaba AND st.ControlGrp = t.ControlGrp
							WHERE s.NotiByContID = st.NotiByContID
								AND t.CustID = ntgt.CustID --TranIDs by CustID
								AND t.TargetSite = ntgt.TargetSite
							ORDER BY t.TransID
							FOR JSON PATH
						)) AS TransIDs
			FROM #tmpNotiByContent AS s
				INNER JOIN #tmpStagingTarget AS ntgt ON s.NotiTempID = ntgt.NotiTempID AND s.IsNoneSaba = ntgt.IsNoneSaba AND s.ControlGrp = ntgt.ControlGrp
			GROUP BY s.NotiByContID
				,ntgt.CustID
				,ntgt.TargetSite

			UNION ALL
			
			--TranIDs by AgentID
			SELECT s.NotiByContID
				,ntgt.AgentID AS TargetID
				,ntgt.TargetSite
				,CONVERT(NVARCHAR(MAX),(
							SELECT DISTINCT t.TransID
							FROM #tmpNotiByContent AS st
								INNER JOIN #tmpStagingTarget AS t ON st.NotiTempID = t.NotiTempID AND st.IsNoneSaba = t.IsNoneSaba AND st.ControlGrp = t.ControlGrp
							WHERE s.NotiByContID = st.NotiByContID
								AND t.AgentID = ntgt.AgentID --TranIDs by AgentID
								AND t.TargetSite = ntgt.TargetSite
							ORDER BY t.TransID
							FOR JSON PATH
						)) AS TransIDs
			FROM #tmpNotiByContent AS s
				INNER JOIN #tmpStagingTarget AS ntgt ON s.NotiTempID = ntgt.NotiTempID AND s.IsNoneSaba = ntgt.IsNoneSaba AND s.ControlGrp = ntgt.ControlGrp
			GROUP BY s.NotiByContID
				,ntgt.AgentID
				,ntgt.TargetSite
			
			UNION ALL
			
			--TranIDs by MasterID
			SELECT s.NotiByContID
				,ntgt.MasterID AS TargetID
				,ntgt.TargetSite
				,CONVERT(NVARCHAR(MAX),(
							SELECT DISTINCT t.TransID
							FROM #tmpNotiByContent AS st
								INNER JOIN #tmpStagingTarget AS t ON st.NotiTempID = t.NotiTempID AND st.IsNoneSaba = t.IsNoneSaba AND st.ControlGrp = t.ControlGrp
							WHERE s.NotiByContID = st.NotiByContID
								AND t.MasterID = ntgt.MasterID --TranIDs by MasterID
								AND t.TargetSite = ntgt.TargetSite
							ORDER BY t.TransID
							FOR JSON PATH
						)) AS TransIDs
			FROM #tmpNotiByContent AS s
				INNER JOIN #tmpStagingTarget AS ntgt ON s.NotiTempID = ntgt.NotiTempID AND s.IsNoneSaba = ntgt.IsNoneSaba AND s.ControlGrp = ntgt.ControlGrp
			GROUP BY s.NotiByContID
				,ntgt.MasterID
				,ntgt.TargetSite
			
			UNION ALL
			
			--TranIDs by SuperID
			SELECT s.NotiByContID
				,ntgt.SuperID AS TargetID
				,ntgt.TargetSite
				,CONVERT(NVARCHAR(MAX),(
							SELECT DISTINCT t.TransID
							FROM #tmpNotiByContent AS st
								INNER JOIN #tmpStagingTarget AS t ON st.NotiTempID = t.NotiTempID AND st.IsNoneSaba = t.IsNoneSaba AND st.ControlGrp = t.ControlGrp
							WHERE s.NotiByContID = st.NotiByContID
								AND t.SuperID = ntgt.SuperID --TranIDs by SuperID
								AND t.TargetSite = ntgt.TargetSite
							ORDER BY t.TransID
							FOR JSON PATH
						)) AS TransIDs
			FROM #tmpNotiByContent AS s
				INNER JOIN #tmpStagingTarget AS ntgt ON s.NotiTempID = ntgt.NotiTempID AND s.IsNoneSaba = ntgt.IsNoneSaba AND s.ControlGrp = ntgt.ControlGrp
			GROUP BY s.NotiByContID
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
			INNER JOIN CTE_AllTarget AS tgt ON i.NotiByContID = tgt.NotiByContID
			
		/*
			Insert NotiMapping
		*/
		INSERT INTO NotiMapping (
			SettlementLogID
			,NotificationID
		)
		SELECT DISTINCT rh.SettlementLogID
			,i.NotificationID
		FROM #tmpInsertedNoti AS i --from Inserted NotificationID --> retrive NotiByContID -> retrive NotiTempID -> SettlementLogID
			INNER JOIN #tmpNotiByContent AS ig ON i.NotiByContID = ig.NotiByContID
			INNER JOIN #tmpResultHist AS rh ON ig.NotiTempID = rh.NotiTempID
		
		/*
			Insert NotificationExtra
		*/		
		;WITH CTE_AffectedResult AS (
			SELECT s.NotiTempID
				,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT t.ResourceID
						,t.ResultName_en
						,t.ResultName_ch
						,t.ResultName_cs
						,t.ActualValue_en
						,t.ActualValue_ch
						,t.ActualValue_cs
						,t.WrongValue_en
						,t.WrongValue_ch
						,t.WrongValue_cs
					FROM #tmpAffectedResult AS t
					WHERE t.NotiTempID = s.NotiTempID
					ORDER BY t.ResourceID
					FOR JSON PATH
				)) AS afResult
			FROM #tmpAffectedResult AS s
			GROUP BY s.NotiTempID
		)
		INSERT INTO NotificationExtra (
			NotificationID
			,EventDate
			,ExtraInfo
		)
		SELECT DISTINCT i.NotificationID
			,rh.EventDate
			,CONVERT(NVARCHAR(MAX),(
				SELECT DISTINCT
					-----support Gen Lap noti-----
					af.afResult AS AffectedResult
					,t.AmendedCnt
					,t.ActionType
					,t.GameSession
					,t.IsNeutral
					,CASE WHEN t.IsNeutral = 1 THEN @Neutral_en END AS NeutralEN ----support AdmSelNoti
					,CASE WHEN t.IsNeutral = 1 THEN @Neutral_ch END AS NeutralCH
					,CASE WHEN t.IsNeutral = 1 THEN @Neutral_cs END AS NeutralCS
					,t.HomeID
					,rfh.RefValueEN AS HomeNameEN --support AdmSelNoti
					,rfh.RefValueCH AS HomeNameCH
					,rfh.RefValueCS AS HomeNameCS
					,t.AwayID
					,rfa.RefValueEN AS AwayNameEN --support AdmSelNoti
					,rfa.RefValueCH AS AwayNameCH
					,rfa.RefValueCS AS AwayNameCS
					,t.LeagueID
					,il.IsNoneSaba AS IsNoneSaba --support AlertSel
					,(CASE WHEN il.IsNoneSaba = 1 THEN TRIM(REPLACE(REPLACE(rfl.RefValueEN,' ' + @Saba_en + ' ',' '),@Saba_en,'')) --REMOVE 'SABA'
						ELSE rfl.RefValueEN END) AS LeagueNameEN
					,(CASE WHEN il.IsNoneSaba = 1 THEN TRIM(REPLACE(REPLACE(rfl.RefValueCS,' ' + @Saba_cs + ' ',' '),@Saba_cs,'')) --REMOVE 'SABA'
						ELSE rfl.RefValueCS END) AS LeagueNameCS
					,(CASE WHEN il.IsNoneSaba = 1 THEN TRIM(REPLACE(REPLACE(rfl.RefValueCH,' ' + @Saba_ch + ' ',' '),@Saba_ch,'')) --REMOVE 'SABA'
						ELSE rfl.RefValueCH END) AS LeagueNameCH
					,t.KOTime --support Chatbot LIC, Alert service
					-----support AdmSelNoti-----
					,t.MatchID
					,t.IsTest
					,c.username AS MsgSender
					,CASE WHEN c.username IS NOT NULL THEN GETDATE() END AS MsgSendDate
					-----support Push Msg Notification-----
					,t.LeagueGroupID
					-----Others-----
					,t.SportType
					,rfs.RefValueEN AS SportNameEN
					,rfs.RefValueCH AS SportNameCH
					,rfs.RefValueCS AS SportNameCS
					,tp.TemplateName
				FROM #tmpResultHist AS t
					LEFT JOIN CTE_AffectedResult AS af ON t.NotiTempID = af.NotiTempID
					LEFT JOIN #tmpRemotingRef AS rfh ON rfh.GroupName = 'EventInfo' AND rfh.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfh.RefId2) = t.HomeID
					LEFT JOIN #tmpRemotingRef AS rfa ON rfa.GroupName = 'EventInfo' AND rfa.RefId1 = 'TeamID' AND TRY_CONVERT(INT,rfa.RefId2) = t.AwayID
					LEFT JOIN #tmpRemotingRef AS rfl ON rfl.GroupName = 'EventInfo' AND rfl.RefId1 = 'LeagueID' AND TRY_CONVERT(INT,rfl.RefId2) = t.LeagueID
					LEFT JOIN #tmpRemotingRef AS rfs ON rfs.GroupName = 'EventInfo' AND rfs.RefId1 = 'SportType' AND TRY_CONVERT(INT,rfs.RefId2) = t.SportType
					LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.CustID = @LogUserID AND i.SuccessStatusID = @StsSending --Sender = [configurated Executor] if IgnoreReviewContent
					LEFT JOIN #tmpStagingNoti AS sn ON t.NotiTempID = sn.NotiTempID
					LEFT JOIN NotiTemplate AS tp WITH (NOLOCK) ON sn.TemplateID = tp.TemplateID
				WHERE t.NotiTempID = il.NotiTempID
				FOR JSON PATH
			)) AS ExtraInfo
		FROM #tmpInsertedNoti AS i
			INNER JOIN #tmpNotiByContent AS il ON i.NotiByContID = il.NotiByContID
			INNER JOIN #tmpResultHist AS rh ON il.NotiTempID = rh.NotiTempID
		
		/*
			Start to final update Notification.StatusID
		*/
		
		-- Check after insert NotiMapping / Notification / NotificationTarget
			-- + Update Notification StatusID = SuccessStatusID
		;WITH CTE_Valid AS (
			SELECT DISTINCT i.NotificationID
				,i.SuccessStatusID
			FROM Notification AS n
				INNER JOIN NotificationTarget AS nt ON n.NotificationID = nt.NotificationID
				INNER JOIN NotiMapping AS nm ON nt.NotificationID = nm.NotificationID
				INNER JOIN NotificationExtra AS ne ON nm.NotificationID = ne.NotificationID
				INNER JOIN #tmpInsertedNoti AS i ON ne.NotificationID = i.NotificationID
			WHERE n.StatusID = @StsGenerating
				AND n.NotificationType = 1 --notification for Msg
		)
		UPDATE n
		SET n.StatusID = v.SuccessStatusID --based on IgnoreReviewContentBySport
		FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
			INNER JOIN CTE_Valid AS v ON n.NotificationID = v.NotificationID
		
		--write log
		;WITH CTE_SettLog AS (
			SELECT NotificationID
				,STRING_AGG(CONVERT(VARCHAR(MAX),SettlementLogID),',') WITHIN GROUP (ORDER BY SettlementLogID) AS SettlIDs
				,STRING_AGG(CONVERT(VARCHAR(MAX),IsNoneSaba),',') AS IsNoneSaba
				,STRING_AGG(CONVERT(VARCHAR(MAX),ControlGrp),',') AS ControlGrp
			FROM (
				SELECT DISTINCT i.NotificationID
					,nm.SettlementLogID
					,nt.IsNoneSaba
					,(CASE WHEN nt.ControlGrp = 0 THEN 'OST' WHEN n.ControlGrp = 1 THEN '777777' ELSE CONVERT(VARCHAR,nt.ControlGrp) END) AS ControlGrp
				FROM #tmpInsertedNoti AS i
					INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON i.NotificationID = nm.NotificationID
					INNER JOIN #tmpNotiByContent AS n ON i.NotiByContID = n.NotiByContID
					INNER JOIN #tmpStagingTarget AS nt ON n.NotiTempID = nt.NotiTempID AND n.IsNoneSaba = nt.IsNoneSaba AND n.ControlGrp = nt.ControlGrp
					
			) AS t
			GROUP BY NotificationID
		)
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT i.NotificationID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + '[Generate Msg Noti process - Gen] - Created Notification Msg with Status = [' + ISNULL(st.Status,CONVERT(VARCHAR,n.StatusID)) + ']'
							+ ' - NotiMapping.SettlementLogID(' + ISNULL(s.SettlIDs,'NULL') + ')'
							+ ' - IsNoneSaba(' + ISNULL(s.IsNoneSaba,'NULL') + ')'
							+ ' - ControlGrp(' + ISNULL(s.ControlGrp,'NULL') + ')'
							+ ' - @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')')
		FROM #tmpInsertedNoti AS i
			INNER JOIN Notification AS n WITH (NOLOCK) ON i.NotificationID = n.NotificationID
			LEFT JOIN CTE_SettLog AS s ON i.NotificationID = s.NotificationID
			LEFT JOIN NotiStatus AS st WITH (NOLOCK) ON n.StatusID = st.StatusID
		ORDER BY i.NotificationID
		
		/*	the rest, change to Failed
			
			because [1 SettlementLogID have many NotificationID(normal, saba)] AND [1 NotificationID have many SettlementLogID(3 SiteDBs)]
				=> SettlementLogID vs NotificationID is Many:Many relationship
				Ex:
					---------------|------------|----------			|		---------------|------------|----------
					SettlementLogID|IsNoneSaba|Status				| 		 NotificationID|IsNoneSaba|Status
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
					SELECT rh.SettlementLogID
						,rh.StatusID
						,rh.NotiLog
						,rh.SessionID
						,rh.SeqNo
						,rh.MatchID
						,rh.IsTest
						,rh.EventDate
						,rh.SportType
						,rh.IsNeutral
						,rh.HomeID
						,rh.AwayID
						,rh.KOTime
						,rh.LeagueID
						,rh.LeagueGroupID
						,rh.GameSession
						,rh.ActionType
						,rh.ActualResultXML
						,rh.WrongResultXML
						,rh.AmendedCnt
						,rh.NotiTempID
						-----------------------
						,n.IsNoneSaba
						,n.TemplateID
						,n.Content_en
						,n.Content_ch
						,n.Content_cs
						-----------------------
						,ntgt.ControlGrp
						,ntgt.TargetSite
						,ntgt.CustID
						,ntgt.AgentID
						,ntgt.MasterID
						,ntgt.SuperID
						,ntgt.TransID
					FROM #tmpResultHist AS rh
						LEFT JOIN #tmpStagingNoti AS n ON rh.NotiTempID = n.NotiTempID
						LEFT JOIN #tmpStagingTarget AS ntgt ON rh.NotiTempID = ntgt.NotiTempID AND n.IsNoneSaba = ntgt.IsNoneSaba
					WHERE rh.SettlementLogID = s.SettlementLogID
					FOR JSON PATH
				)) AS LTxt
			FROM #tmpResultHist AS s
		)
		,CTE_SLog AS (
			SELECT nm.SettlementLogID
				,STRING_AGG(CONVERT(NVARCHAR(MAX),nm.NotificationID),',') AS NotiIDs
			FROM #tmpInsertedNoti AS i
				INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON i.NotificationID = nm.NotificationID
			GROUP BY nm.SettlementLogID
		)
		,CTE_NotiSts AS (
			SELECT nm.SettlementLogID
				,MIN(CASE WHEN ISNULL(n.StatusID, -1) <> i.SuccessStatusID THEN 0
						ELSE 1 END) AS ValidSts
			FROM #tmpInsertedNoti AS i
				INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON i.NotificationID = nm.NotificationID
				LEFT JOIN Notification AS n WITH (NOLOCK) ON i.NotificationID = n.NotificationID
			GROUP BY nm.SettlementLogID
		)
		UPDATE rh
		SET rh.StatusID = (CASE WHEN ISNULL(ns.ValidSts,0) = 1 THEN @StsGenerated ELSE @StsGenFailed END)
			,rh.NotiLog = rh.NotiLog + (CASE WHEN ISNULL(ns.ValidSts,0) = 1 THEN 'Changed SettlementLogID Status from [Generating] to [Successfully Generated] - NotiIDs(' + ISNULL(sl.NotiIDs,'NULL') + ')'
							ELSE ' - All Info as JSON = ' + ISNULL(el.LTxt,'NULL') END) --error log write bellow
		FROM #tmpResultHist AS rh
			LEFT JOIN CTE_NotiSts AS ns ON rh.SettlementLogID = ns.SettlementLogID
			LEFT JOIN CTE_SLog AS sl ON rh.SettlementLogID = sl.SettlementLogID
			LEFT JOIN CTE_ELog AS el ON rh.SettlementLogID = el.SettlementLogID
		
		--get Failed NotiID
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
		INSERT INTO #tmpFailedNoti (NotificationID)
		SELECT DISTINCT NotificationID
		FROM CTE_FailedNoti
		
		--DEL Failed NotiID
			--Notification
			--NotificationTarget
			--NotiMapping
			--NotificationExtra
		DELETE FROM Notification
		WHERE NotificationID IN (SELECT NotificationID FROM #tmpFailedNoti)
		
		DELETE FROM NotificationTarget
		WHERE NotificationID IN (SELECT NotificationID FROM #tmpFailedNoti)
		
		DELETE FROM NotiMapping
		WHERE NotificationID IN (SELECT NotificationID FROM #tmpFailedNoti)
		
		DELETE FROM NotificationExtra
		WHERE NotificationID IN (SELECT NotificationID FROM #tmpFailedNoti)
		
		--write log
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT NotificationID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + '[Generate Msg Noti process - Gen] - Deleted Notification after consistency checking')
		FROM #tmpFailedNoti AS i
		ORDER BY i.NotificationID
			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Insert new Msg Notification - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	--write log
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + '[Generate Msg Noti process - Gen] - Inserted new Notification'
						+ ' - tmpInsertedNoti('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpInsertedNoti
										ORDER BY NotificationID
											,NotiByContID
										FOR JSON PATH
									))
								),'NO ROW') + ')'
						+ ' - tmpFailedNoti('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpFailedNoti
										ORDER BY NotificationID
										FOR JSON PATH
									))
								),'NO ROW') + ')')
	/****************************************************************************
		Final mark Failed if @ErrCode <> 0
	****************************************************************************/
	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
		UPDATE #tmpResultHist
		SET StatusID = @StsGenFailed
			,NotiLog = NotiLog + '[Generate Msg Noti process - Gen] - Changed SettlementLogID Status from [Generating] to [Failed to Generate] due to ERROR('+ ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL') + ') - ERROR_MESSAGE('+ ISNULL(@ErrMsg,'NULL') + ')'
		
		--DEL Failed NotiID
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
		IF EXISTS (
			SELECT 1
			FROM #tmpInsertedNoti AS i
				LEFT JOIN #tmpFailedNoti AS f ON i.NotificationID = f.NotificationID
			WHERE f.NotificationID IS NULL
		)
		BEGIN
			--write log
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT i.NotificationID
				,@LogActionID
				,@LogUserID
				,COMPRESS(@ErrLogPrefix + '[Generate Msg Noti process - Gen] - Recent [Notification] inserts have been removed - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
			FROM #tmpInsertedNoti AS i
				LEFT JOIN #tmpFailedNoti AS f ON i.NotificationID = f.NotificationID
			WHERE f.NotificationID IS NULL --FailedNoti log above
			ORDER BY i.NotificationID
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
				,COMPRESS(@ErrLogPrefix + '[Generate Msg Noti process - Gen] - ' + ISNULL(@ErrMsg,'NULL'))
		END
	END
	
	--Final update SettlementResultHist
	UPDATE sh
	SET sh.StatusID = rh.StatusID
		,sh.LastModifiedTime = GETDATE()
	FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpResultHist AS rh ON sh.SettlementLogID = rh.SettlementLogID
	
	--write log
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT SettlementLogID
		,@LogActionID
		,@LogUserID
		,COMPRESS((CASE WHEN StatusID = @StsGenerated THEN @InfLogPrefix ELSE @ErrLogPrefix END) + ISNULL(rh.NotiLog,'SettlementLog NULL'))
	FROM #tmpResultHist AS rh
	ORDER BY SettlementLogID
	
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
		,COMPRESS(@InfLogPrefix + 'Completed [Generate Msg Noti process - Gen] - change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']') AS LogBef
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = @ProcessID
	
	DROP TABLE #tmpRemotingRef
	DROP TABLE #tmpResultHist
	DROP TABLE #tmpStagingNoti
	DROP TABLE #tmpStagingTarget
	DROP TABLE #tmpTemplateDetl
	DROP TABLE #tmpNotiByContent
	DROP TABLE #tmpInsertedNoti
	DROP TABLE #tmpResultInfo
	DROP TABLE #tmpAffectedResult
	DROP TABLE #tmpFailedNoti
END
