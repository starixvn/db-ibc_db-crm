/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_SettlResultHist_DataLoad
	@Environment VARCHAR(20)
	,@JSSettlResultHist NVARCHAR(MAX)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Data loading from all SiteDBs
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
		@JSSettlResultHist: data from SiteDBs (output of MNC_SettlResultHist_GetSessionByDate)
		
		Steps
			- Load setting
			- Load data from web (Parse JSON data)
			- Insert into SettlementResultHist with Status = Retrieving
				+ Insert if NOT EXISTS
				+ The UNIQUE KEY of SettlementResultHist (SessionID,MatchID,SeqNo)
			- Insert into SettlementResultHistDetail
				+ Only for NEW SettlementLogID from above step
				+ Write log for case EXISTING SettlementLogID but SettlementResultHistDetail <> @JSSettlResultHist
			- Update SettlementResultHist.Status = Retrieve Completed WHERE Status = Retrieving
				+ CASE #1: Count of SiteDBGroupID By [SessionID] = Count of SiteDBConfig (UPD only for StatusID = Retrieving)
				+ CASE #2: SessionID inserted too long (over configuration time in SystemSetting)
	
	Example:
		EXEC MessageNotification.dbo.MNC_SettlResultHist_DataLoad
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@SiteDBGroupID SMALLINT
		,@ProcessID INT
		,@UATMode BIT = 0
		,@LogMode VARCHAR(50)
		,@IsTestFlag BIT
		,@StsRetrieving TINYINT
		,@StsRetrieved TINYINT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
	
	/*
		**************************************************Load setting**************************************************
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @ProcessID = (
		CASE WHEN @Environment = 'LIVE' THEN 4 --Process_CaptureData
			ELSE 7 END --ProcessUAT_CaptureData
	)
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @StsRetrieving = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Retrieving'
	
	SELECT @StsRetrieved = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Successfully Retrieved'
	
	SELECT @UATMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --UATMode
	
	SELECT @LogMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
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
			,COMPRESS(@InfLogPrefix + '[Capture process - DataLoad] - NO Action for UATMode = OFF AND Environment = UAT')
		
		RETURN
	END
	ELSE IF @UATMode = 1 AND @Environment = 'LIVE' --REAL data only
	BEGIN
		SET @IsTestFlag = 0
	END
	ELSE IF @UATMode = 1 AND @Environment = 'UAT' --TEST data only
	BEGIN
		SET @IsTestFlag = 1
	END
	ELSE --both REAL & TEST
	BEGIN
		SET @IsTestFlag = NULL
	END
	
	--write log
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Start [Capture process - DataLoad] with @UATMode(' + ISNULL(CONVERT(VARCHAR,@UATMode),'NULL') + ')'
						+ ', @Environment(' + ISNULL(@Environment,'NULL') + ')'
						+ ', @JSSettlResultHist(' + ISNULL(@JSSettlResultHist,'NULL') + ')')
	
	CREATE TABLE #tmpJSData (
		ObjectName NVARCHAR(150)
		,JSONData NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpResultHist (
		SiteDBGroupID SMALLINT
		,SessionID VARCHAR(50)
		,MatchID INT
		,IsTest BIT
		,SeqNo SMALLINT
		,SettlementStatusID TINYINT
		,ActualResult VARCHAR(MAX)
		,WrongResult VARCHAR(MAX)
		,ActionType TINYINT
		,ResultType TINYINT
		,SportType INT
		,CreatedTime DATETIME
		,ExtraInfo VARCHAR(MAX)
	)
	
	CREATE TABLE #tmpInsertedRH (
		SettlementLogID INT NOT NULL
		,SessionID VARCHAR(50)
		,SeqNo SMALLINT
	)
	
	CREATE TABLE #tmpResultHistDetail (
		SessionID VARCHAR(50)
		,SeqNo SMALLINT
		,Transid BIGINT
		,CustID INT
		,ExtraInfo_Before VARCHAR(MAX)
		,ExtraInfo_After VARCHAR(MAX)
	)
	
	CREATE TABLE #tmpInsertedRHDetail (
		SettlementLogID INT NOT NULL
		,Transid BIGINT NOT NULL
		,CustID INT
	)
	
	CREATE TABLE #tmpBalanceNegativeHistory (
		LogID BIGINT
		,ExecDate DATETIME
		,MatchID INT
		,ActionID INT
		,CustID INT
		,GroupID INT
		,Balance MONEY
		,TotalBalance MONEY
		,Site VARCHAR(50)
		,SessionID VARCHAR(50)
	)
	
	CREATE TABLE #tmpInsertedNB (
		SessionID VARCHAR(50)
		,MatchID INT
		,CustID INT
		,LogID BIGINT
	)
	
	--keep data incase rollback
	DECLARE @tmpUpdatedRH TABLE (
		SettlementLogID INT NOT NULL
		,UpdatedCase VARCHAR(50)
	)
	/*
		**************************************************Load data from web**************************************************
	*/
	BEGIN TRY
		INSERT INTO #tmpJSData(
			ObjectName
			,JSONData
		)
		SELECT ObjectName
			,JSONData
		FROM OPENJSON(@JSSettlResultHist) WITH (
				ObjectName NVARCHAR(150) '$.ObjectName'
				,JSONData NVARCHAR(MAX) '$.JSONData'
			)--OPENJSON case-sensitive
		
		--get @SiteDBGroupID
		SELECT @SiteDBGroupID = TRY_CONVERT(SMALLINT,JSONData)
		FROM #tmpJSData
		WHERE ObjectName = 'SiteDBGroupID'
		
		INSERT INTO #tmpResultHist (
			SiteDBGroupID
			,SessionID
			,MatchID
			,IsTest
			,SeqNo
			,SettlementStatusID
			,ActualResult
			,WrongResult
			,ActionType
			,ResultType
			,SportType
			,CreatedTime
			,ExtraInfo
		)
		SELECT @SiteDBGroupID
			,SessionID
			,MatchID
			,IsTest
			,SeqNo
			,StatusID
			,ActualResult
			,WrongResult
			,ActionType
			,ResultType
			,SportType
			,CreatedDate
			,ExtraInfo
		FROM OPENJSON((SELECT JSONData FROM #tmpJSData WHERE ObjectName = 'SettlementResultHistory')) WITH (
				SessionID VARCHAR(50) '$.SessionID'
				,MatchID INT '$.MatchID'
				,IsTest BIT '$.IsTest'
				,SeqNo SMALLINT '$.SeqNo'
				,StatusID TINYINT '$.StatusID'
				,ActualResult VARCHAR(MAX) '$.ActualResult'
				,WrongResult VARCHAR(MAX) '$.WrongResult'
				,ActionType TINYINT '$.ActionType'
				,ResultType TINYINT '$.ResultType'
				,SportType INT '$.SportType'
				,CreatedDate DATETIME '$.CreatedDate'
				,ExtraInfo VARCHAR(MAX) '$.ExtraInfo'
			)--OPENJSON case-sensitive
		WHERE IsTest = ISNULL(@IsTestFlag,IsTest)
		
		INSERT INTO #tmpResultHistDetail (
			SessionID
			,SeqNo
			,Transid
			,CustID
			,ExtraInfo_Before
			,ExtraInfo_After
		)
		SELECT SessionID
			,SeqNo
			,Transid
			,CustID
			,ExtraInfo_Before
			,ExtraInfo_After
		FROM OPENJSON((SELECT JSONData FROM #tmpJSData WHERE ObjectName = 'SettlementResultHistory_TicketDetails')) WITH (
				SessionID VARCHAR(50) '$.SessionID'
				,SeqNo SMALLINT '$.SeqNo'
				,Transid BIGINT '$.Transid'
				,CustID INT '$.CustID'
				,ExtraInfo_Before VARCHAR(MAX) '$.ExtraInfo_Before'
				,ExtraInfo_After VARCHAR(MAX) '$.ExtraInfo_After'
			)--OPENJSON case-sensitive
		
		INSERT INTO #tmpBalanceNegativeHistory (
			SessionID
			,CustID
			,Site
			,LogID
			,ExecDate
			,MatchID
			,ActionID
			,GroupID
			,Balance
			,TotalBalance
		)
		SELECT SessionID
			,CustID
			,Site
			,LogID
			,ExecDate
			,MatchID
			,ActionID
			,GroupID
			,Balance
			,TotalBalance
		FROM OPENJSON((SELECT JSONData FROM #tmpJSData WHERE ObjectName = 'BalanceNegativeHistory')) WITH (
				SessionID VARCHAR(50) '$.SessionID'
				,CustID INT '$.CustID'
				,Site VARCHAR(50) '$.Site'
				,LogID BIGINT '$.LogID'
				,ExecDate DATETIME '$.ExecDate'
				,MatchID INT '$.MatchID'
				,ActionID INT '$.ActionID'
				,GroupID INT '$.GroupID'
				,Balance MONEY '$.Balance'
				,TotalBalance MONEY '$.TotalBalance'
			)--OPENJSON case-sensitive
	
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + '[Capture process - DataLoad] - FAILED to Parse JSON Data'
								+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
								+ ' - @JSSettlResultHist(' + ISNULL(@JSSettlResultHist,'NULL') + ')'
								+ ' - @IsTestFlag(' + ISNULL(CONVERT(VARCHAR,@IsTestFlag),'both REAL & TEST') + ')'
								+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
	END CATCH
	
	/*
		**************************************************Start to insert SettlementResultHist**************************************************
		
		Only Insert if SettlementStatusID = 2 (Completed)
		
		SettlementStatusID = [SITEDB1,2,3].SettlementResultHistory.StatusID
								NULL: Init
								0: Done Settlement (SP version)
								1: Done Settlement  (SP orgi - QueueDb)
								2: Complete to insert affected tickets  & negative balance if any (Sitedb1,2) for result amendment -> Ready to use data (insert Msg/MsgTarget) for notification
								3. after 30minutes, if still = 1 then notification to sas, pontus, update statusid failed = 3
								4: complete to process in case having settlement queue failed
								99: settlement queue failed
	*/
	IF @ErrCode = 0
	BEGIN TRY
		INSERT INTO SettlementResultHist (
			StatusID
			,SiteDBGroupID
			,SessionID
			,MatchID
			,IsTest
			,SeqNo
			,ActualResult
			,WrongResult
			,ActionType
			,ResultType
			,SportType
			,CreatedTime
			,ExtraInfo
			,InsertedTime
		)
		OUTPUT INSERTED.SettlementLogID
			,INSERTED.SessionID
			,INSERTED.SeqNo
		INTO #tmpInsertedRH (
			SettlementLogID
			,SessionID
			,SeqNo
		) --Get Inserted SettlementLogID
		SELECT @StsRetrieving AS StatusID
			,SiteDBGroupID
			,SessionID
			,MatchID
			,IsTest
			,SeqNo
			,ActualResult
			,WrongResult
			,ActionType
			,ResultType
			,SportType
			,CreatedTime
			,ExtraInfo
			,GETDATE() AS InsertedTime
		FROM #tmpResultHist AS rh
		WHERE rh.SettlementStatusID = 2 --2-Completed Result Amendment
			AND NOT EXISTS (
				SELECT 1
				FROM SettlementResultHist AS tgt
				WHERE rh.SessionID = tgt.SessionID
					AND rh.MatchID = tgt.MatchID
					AND rh.SeqNo = tgt.SeqNo
					AND rh.SiteDBGroupID = tgt.SiteDBGroupID
			) --UNIQUE KEY (SessionID,MatchID,SeqNo,SiteDBGroupID)
		
		--write log
		IF EXISTS (SELECT 1 FROM #tmpInsertedRH)
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT SettlementLogID
				,@LogActionID
				,@LogUserID
				,COMPRESS(@InfLogPrefix + 'INSERTED SettlementResultHist with StatusID(' + ISNULL(s.Status,'NULL') + ')')
			FROM #tmpInsertedRH AS i
				LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON s.StatusID = @StsRetrieving
			ORDER BY SettlementLogID
		ELSE
			INSERT INTO UserLog (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,COMPRESS(@InfLogPrefix + 'Debug - NO ROW inserted SettlementResultHist')
			WHERE @LogMode = 'Debug'
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + '[Capture process - DataLoad] - FAILED INSERT INTO SettlementResultHist'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - @JSSettlResultHist (' + ISNULL(@JSSettlResultHist,'NULL') + ')'
							+ ' - Prepared data('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpResultHist
										FOR JSON PATH
									))
								),'NO ROW') + ')'
							+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
	END CATCH
	
	/*
		**************************************************Start to insert SettlementResultHistDetail**************************************************
		+ For new SettlementLogID
	*/
	IF @ErrCode = 0 AND EXISTS (SELECT 1 FROM #tmpInsertedRH)
	BEGIN TRY
		INSERT INTO SettlementResultHistDetail (
			SettlementLogID
			,Transid
			,CustID
			,ExtraInfo_Before
			,ExtraInfo_After
		)
		OUTPUT INSERTED.SettlementLogID
			,INSERTED.Transid
			,INSERTED.CustID
		INTO #tmpInsertedRHDetail (
			SettlementLogID
			,Transid
			,CustID
		) --Get Inserted detail
		SELECT DISTINCT rh.SettlementLogID
			,rhd.Transid
			,rhd.CustID
			,rhd.ExtraInfo_Before
			,rhd.ExtraInfo_After
		FROM #tmpInsertedRH AS rh
			INNER JOIN #tmpResultHistDetail AS rhd ON rh.SessionID = rhd.SessionID AND rh.SeqNo = rhd.SeqNo
		WHERE NOT EXISTS (
				SELECT 1
				FROM SettlementResultHistDetail AS tgt
				WHERE rh.SettlementLogID = tgt.SettlementLogID
					AND rhd.Transid = tgt.Transid
					AND rhd.CustID = tgt.CustID
			)
		
		--write log
		;WITH CTE_InsertedDetail AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
								SELECT t.TransID
									,t.CustID
									,t.ExtraInfo_Before
									,t.ExtraInfo_After
								FROM #tmpResultHistDetail AS t
									INNER JOIN #tmpInsertedRH AS rh ON rh.SessionID = t.SessionID AND rh.SeqNo = t.SeqNo
								WHERE rh.SettlementLogID = s.SettlementLogID
									AND t.Transid = s.Transid
									AND t.CustID = s.CustID
								ORDER BY TransID
								FOR JSON PATH
							)) AS LTxt
			FROM #tmpInsertedRHDetail AS s
		)
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT rh.SettlementLogID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + (CASE WHEN @LogMode = 'Debug' THEN 'Debug - ' ELSE '' END ) + 'INSERTED SettlementResultHistDetail (' + ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX),d.LTxt),','),'NO ROW')+ ')')
		FROM #tmpInsertedRH AS rh
			LEFT JOIN CTE_InsertedDetail AS d ON rh.SettlementLogID = d.SettlementLogID
		WHERE @LogMode = 'Debug'
			OR EXISTS (SELECT 1 FROM #tmpInsertedRHDetail)
		GROUP BY rh.SettlementLogID
		ORDER BY rh.SettlementLogID
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + '[Capture process - DataLoad] - FAILED INSERT INTO SettlementResultHistDetail'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - @JSSettlResultHist (' + ISNULL(@JSSettlResultHist,'NULL') + ')'
							+ ' - Prepared data('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpResultHistDetail
										FOR JSON PATH
									))
								),'NO ROW') + ')'
							+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		--Remove Inserted SettlementLogID
		DELETE sh
		FROM SettlementResultHistDetail AS sh
			INNER JOIN #tmpInsertedRH AS rh ON sh.SettlementLogID = rh.SettlementLogID
		
		DELETE sh
		FROM SettlementResultHist AS sh
			INNER JOIN #tmpInsertedRH AS rh ON sh.SettlementLogID = rh.SettlementLogID
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT SettlementLogID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'Recent [SettlementResultHist] inserts have been removed because [SettlementResultHistDetail] failed to insert.')
		FROM #tmpInsertedRH
		ORDER BY SettlementLogID
		
	END CATCH
	
	/*
		**************************************************Start to insert BalanceNegativeHist**************************************************
		+ For new SettlementLogID
	*/
	IF @ErrCode = 0 AND EXISTS (SELECT 1 FROM #tmpInsertedRHDetail)
	BEGIN TRY
		/*
			Currently, BalanceNegativeHistory mapped by SessionID
			
			BUT SettlementResultHistory break SessionID / SeqNo
			
			Paid Attention when handling SessionID / CustID
		*/
		INSERT INTO BalanceNegativeHist (
			SessionID
			,CustID
			,Site
			,LogID
			,ExecDate
			,MatchID
			,ActionID
			,GroupID
			,Balance
			,TotalBalance
		)
		OUTPUT INSERTED.SessionID
			,INSERTED.MatchID
			,INSERTED.CustID
			,INSERTED.LogID
		INTO #tmpInsertedNB (
			SessionID
			,MatchID
			,CustID
			,LogID
		) --Get Inserted Negative
		SELECT DISTINCT bn.SessionID
			,bn.CustID
			,bn.Site
			,bn.LogID
			,bn.ExecDate
			,bn.MatchID
			,bn.ActionID
			,bn.GroupID
			,bn.Balance
			,bn.TotalBalance
		FROM #tmpInsertedRHDetail AS rhd
			INNER JOIN #tmpInsertedRH AS rh ON rh.SettlementLogID = rhd.SettlementLogID
			INNER JOIN #tmpResultHist AS rs ON rh.SessionID = rs.SessionID AND rh.SeqNo = rs.SeqNo
			INNER JOIN #tmpBalanceNegativeHistory AS bn ON rh.SessionID = bn.SessionID AND rs.MatchID = bn.MatchID AND rhd.CustID = bn.CustID
		WHERE NOT EXISTS (
				SELECT 1
				FROM BalanceNegativeHist AS tgt
				WHERE bn.SessionID = tgt.SessionID
					AND bn.MatchID = tgt.MatchID
					AND bn.CustID = tgt.CustID
					AND bn.LogID = tgt.LogID
			)
		
		--write log
		;WITH CTE_InsertedNB AS (
			SELECT s.SessionID
				,CONVERT(NVARCHAR(MAX),(
								SELECT DISTINCT t.*
								FROM #tmpInsertedNB AS t
								WHERE t.SessionID = s.SessionID
								ORDER BY LogID
								FOR JSON PATH
							)) AS LTxt
			FROM #tmpInsertedNB AS s
			GROUP BY s.SessionID
		)
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT rh.SettlementLogID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + (CASE WHEN @LogMode = 'Debug' THEN 'Debug - ' ELSE '' END ) + 'INSERTED BalanceNegativeHist (' + ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX),bn.LTxt),','),'NO ROW')+ ')')
		FROM #tmpInsertedRH AS rh
			LEFT JOIN CTE_InsertedNB AS bn ON rh.SessionID = bn.SessionID
		WHERE @LogMode = 'Debug'
			OR EXISTS (SELECT 1 FROM #tmpInsertedNB)
		GROUP BY rh.SettlementLogID
		ORDER BY rh.SettlementLogID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + '[Capture process - DataLoad] - FAILED INSERT INTO BalanceNegativeHist'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - @JSSettlResultHist (' + ISNULL(@JSSettlResultHist,'NULL') + ')'
							+ ' - Prepared data('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpBalanceNegativeHistory
										FOR JSON PATH
									))
								),'NO ROW') + ')'
							+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		--Remove Inserted SettlementLogID
		
		DELETE sh
		FROM BalanceNegativeHist AS sh
			INNER JOIN #tmpInsertedRH AS rh ON sh.SessionID = rh.SessionID
			LEFT JOIN #tmpInsertedNB AS bn ON sh.SessionID = bn.SessionID AND sh.MatchID = bn.MatchID AND sh.CustID = bn.CustID AND sh.LogID = bn.LogID
			LEFT JOIN #tmpInsertedRHDetail AS rhd ON rh.SettlementLogID = rhd.SettlementLogID AND sh.CustID = rhd.CustID
		WHERE ISNULL(bn.CustID,rhd.CustID) IS NOT NULL
			
		
		DELETE sh
		FROM SettlementResultHistDetail AS sh
			INNER JOIN #tmpInsertedRH AS rh ON sh.SettlementLogID = rh.SettlementLogID
		
		DELETE sh
		FROM SettlementResultHist AS sh
			INNER JOIN #tmpInsertedRH AS rh ON sh.SettlementLogID = rh.SettlementLogID
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT SettlementLogID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'Recent [SettlementResultHist] inserts have been removed because [BalanceNegativeHist] failed to insert.')
		FROM #tmpInsertedRH
		ORDER BY SettlementLogID
		
	END CATCH
	
	/*
		**************************************************SettlementResultHist.Status = Successfully Retrieved**************************************************
		
		SettlementStatusID = [SITEDB1,2,3].SettlementResultHistory.StatusID
								NULL: Init
								0: Done Settlement (SP version)
								1: Done Settlement  (SP orgi - QueueDb)
								2: Complete to insert affected tickets  & negative balance if any (Sitedb1,2) for result amendment -> Ready to use data (insert Msg/MsgTarget) for notification
								3. after 30minutes, if still = 1 then notification to sas, pontus, update statusid failed = 3
								4: complete to process in case having settlement queue failed
								99: settlement queue failed
		
			CASE #1: Count of SiteDBGroupID By [SessionID] = Count of SiteDBConfig (UPD only for StatusID = Retrieving)
			CASE #2: SessionID inserted too long (over configuration time in SystemSetting)
	*/
	IF @ErrCode = 0
	BEGIN TRY
		DECLARE @SiteDBCnt INT = 0
		
		SELECT @SiteDBCnt = COUNT(DISTINCT SiteDBGroupID)
		FROM bodb02.dbo.SiteDBConfig WITH (NOLOCK)
		WHERE SiteDBGroupID <> 0
		
		BEGIN TRANSACTION --lock Retrieving SettlementResultHist for UPD Status
			
			/*
				Update for CASE #1
					Count of SiteDBGroupID By [SessionID] = Count of SiteDBConfig (UPD only for StatusID = Retrieving)
			*/
			;WITH CTE_Session AS (
				SELECT sh.SessionID
					,sh.MatchID
					,sh.SeqNo
					,sh.SiteDBGroupID
				FROM #tmpResultHist AS rh
					INNER JOIN SettlementResultHist AS sh ON rh.SessionID = sh.SessionID --case SettlementStatusID=2
				WHERE sh.IsTest = ISNULL(@IsTestFlag,sh.IsTest)
				
				UNION ALL
				
				SELECT SessionID
					,MatchID
					,SeqNo
					,SiteDBGroupID
				FROM #tmpResultHist
				WHERE SettlementStatusID > 2 ----can ignore Session
			)
			,CTE_Sts AS (
				SELECT SessionID
					,MatchID
					,SeqNo
					,COUNT(DISTINCT SiteDBGroupID) AS SiteDBCnt
				FROM CTE_Session
				GROUP BY SessionID
					,MatchID
					,SeqNo
			)
			UPDATE sh
			SET sh.StatusID = @StsRetrieved
				,sh.LastModifiedTime = GETDATE()
			OUTPUT INSERTED.SettlementLogID
				,'Full SiteDBGroupIDs'
			INTO @tmpUpdatedRH (SettlementLogID, UpdatedCase)
			FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
				INNER JOIN CTE_Sts AS sts ON sh.SessionID = sts.SessionID AND sh.MatchID = sts.MatchID AND sh.SeqNo = sts.SeqNo
			WHERE sts.SiteDBCnt = @SiteDBCnt
				AND sh.StatusID = @StsRetrieving
			
			--write log
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT i.SettlementLogID
				,@LogActionID
				,@LogUserID
				,COMPRESS(@InfLogPrefix + 'Changed Status from [Retrieving] to [Successfully Retrieved] (All data from SiteDBConfig.SiteDBGroupIDs is loaded)')
			FROM @tmpUpdatedRH AS i
			WHERE UpdatedCase = 'Full SiteDBGroupIDs'
			ORDER BY i.SettlementLogID
		
		COMMIT TRANSACTION
		
		BEGIN TRANSACTION
			/*
				Update for CASE #2
					SessionID inserted too long (over configuration time in SystemSetting)
			*/
			DECLARE @Retrieving_WaitSec INT = 0
			
			SELECT @Retrieving_WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0)
			FROM SystemSetting WITH (NOLOCK)
			WHERE VID = 11 --Retrieving_WaitSec
			
			;WITH CTE_Session_INSTime AS (
				SELECT SessionID
				FROM SettlementResultHist
				WHERE StatusID = @StsRetrieving
				GROUP BY SessionID
				HAVING DATEDIFF(SECOND, MIN(InsertedTime),GETDATE()) > @Retrieving_WaitSec
			)
			UPDATE sh
			SET sh.StatusID = @StsRetrieved
				,sh.LastModifiedTime = GETDATE()
			OUTPUT INSERTED.SettlementLogID
				,'Over Retrieving_WaitSec'
			INTO @tmpUpdatedRH (SettlementLogID, UpdatedCase)
			FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
				INNER JOIN CTE_Session_INSTime AS s ON sh.SessionID = s.SessionID
			WHERE sh.StatusID = @StsRetrieving
			
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
				,COMPRESS(@InfLogPrefix + 'Changed Status from [Retrieving] to [Successfully Retrieved] - Over Retrieving_WaitSec(' + ISNULL(CONVERT(VARCHAR,@Retrieving_WaitSec),'NULL') +') configuration')
			FROM @tmpUpdatedRH AS rh
			WHERE UpdatedCase = 'Over Retrieving_WaitSec'
			ORDER BY SettlementLogID
	
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		ROLLBACK TRANSACTION
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + '[Capture process - DataLoad] - FAILED UPDATE SettlementResultHist.Status'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - @JSSettlResultHist(' + ISNULL(@JSSettlResultHist,'NULL') + ')'
							+ ' - tmpInsertedRH('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpInsertedRH
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - tmpInsertedRHDetail('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpInsertedRHDetail
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - tmpInsertedNB('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpInsertedNB
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - Update SettlementResultHist status('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM @tmpUpdatedRH
											FOR JSON PATH
										))
									),'NO ROW') + ')'
							+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')

	END CATCH
	
	/**************************************************Mark Capture process DONE**************************************************/
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
		,COMPRESS(@InfLogPrefix + 'Completed [Capture process - DataLoad]'
						+ ' - @SiteDBGroupID(' + ISNULL(CONVERT(VARCHAR,@SiteDBGroupID),'NULL') + ')'
						+ ' - Change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']') AS LogBef
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = @ProcessID
	
	--write more info if LogMode = Debug
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Debug - Completed [Capture process - DataLoad]'
						+ ' - @SiteDBGroupID(' + ISNULL(CONVERT(VARCHAR,@SiteDBGroupID),'NULL') + ')'
						+ ' - Inserted SettlementResultHist('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpInsertedRH
										FOR JSON PATH
									))
								),'NO ROW') + ')'
						+ ' - Inserted SettlementResultHistDetail('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpInsertedRHDetail
										FOR JSON PATH
									))
								),'NO ROW') + ')'
						+ ' - Inserted BalanceNegativeHist('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpInsertedNB
										FOR JSON PATH
									))
								),'NO ROW') + ')'
						+ ' - Updated SettlementResultHist.Status('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM @tmpUpdatedRH
										FOR JSON PATH
									))
								),'NO ROW') + ')')
	WHERE @LogMode = 'Debug'
	
	DROP TABLE #tmpJSData
	DROP TABLE #tmpResultHist
	DROP TABLE #tmpInsertedRH
	DROP TABLE #tmpResultHistDetail
	DROP TABLE #tmpInsertedRHDetail
	DROP TABLE #tmpBalanceNegativeHistory
	DROP TABLE #tmpInsertedNB
END
