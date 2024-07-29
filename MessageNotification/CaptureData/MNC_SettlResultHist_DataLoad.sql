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
			If IncludeTestMatch = ON
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If IncludeTestMatch = OFF
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
	
	/*
		Reset OUTPUT
	*/
	SELECT @ErrCode = 0
		,@ErrMsg = ''
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@SiteDBGroupID SMALLINT
		,@ProcessID INT
		,@PRODIncludeTest BIT = 0
		,@LogMode VARCHAR(50)
		,@IsTestFlag BIT
		,@StsRetrieving TINYINT
		,@StsRetrieved TINYINT
		,@StsRetrvFailed TINYINT
		,@CurrTime DATETIME = GETDATE()
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
	
	/*
		**************************************************Load setting**************************************************
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @StsRetrieving = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Retrieving'
	
	SELECT @StsRetrieved = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Successfully Retrieved'
	
	SELECT @StsRetrvFailed = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Failed to Retrieve'
	
	SELECT @PRODIncludeTest = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --IncludeTestMatch
	
	SELECT @LogMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	IF @Environment = 'LIVE'
	BEGIN
		SELECT @ProcessID = 4 --CaptureDataService
		SELECT @ErrLogPrefix = 'Error - [CaptureDataService - DataLoad] - '
		SELECT @InfLogPrefix = 'Info - [CaptureDataService - DataLoad] - '
	END
	ELSE
	BEGIN
		SELECT @ProcessID = 7 --UAT_CaptureDataService
		SELECT @ErrLogPrefix = 'Error - [UAT_CaptureDataService - DataLoad] - '
		SELECT @InfLogPrefix = 'Info - [UAT_CaptureDataService - DataLoad] - '
		
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
		SELECT @ErrCode = 50001 --user-defined error code
			,@ErrMsg = 'NO Action for IncludeTestMatch = ON AND Environment = UAT'
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'NO Action for IncludeTestMatch = ON AND Environment = UAT')
		
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
	
	--write log
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'IncludeTestMatch(' + ISNULL(CONVERT(VARCHAR,@PRODIncludeTest),'NULL') + ')'
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
		,IsDeleted BIT
	)
	
	CREATE TABLE #tmpInsertedRH (
		SettlementLogID INT NOT NULL
		,SessionID VARCHAR(50)
		,SeqNo SMALLINT
		,ActionDesc VARCHAR(50)
	)
	
	CREATE TABLE #tmpResultHistDetail (
		SessionID VARCHAR(50)
		,SeqNo SMALLINT
		,Transid BIGINT
		,CustID INT
		,ExtraInfo_Before VARCHAR(MAX)
		,ExtraInfo_After VARCHAR(MAX)
		,IsDeleted BIT
	)
	
	CREATE TABLE #tmpInsertedRHDetail (
		SettlementLogID INT NOT NULL
		,Transid BIGINT NOT NULL
		,CustID INT
	)
	
	CREATE TABLE #tmpBalanceNegativeHist (
		SessionID VARCHAR(50)
		,MatchID INT
		,SiteDBGroupID SMALLINT
		,CustID INT
		,Site VARCHAR(50)
		,Balance MONEY
		,TotalBalance MONEY
	)
	
	CREATE TABLE #tmpInsertedNB (
		SessionID VARCHAR(50)
		,MatchID INT
		,CustID INT
		,SiteDBGroupID SMALLINT
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
		WHERE ISJSON(@JSSettlResultHist) = 1
		
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
			,IsDeleted
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
			,IsDeleted
		FROM OPENJSON((SELECT JSONData FROM #tmpJSData WHERE ObjectName = 'SettlementResultHistory' AND ISJSON(JSONData) = 1)) WITH (
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
				,IsDeleted BIT '$.IsDeleted'
			)--OPENJSON case-sensitive
		WHERE @IsTestFlag IS NULL
			OR IsTest = @IsTestFlag
		
		CREATE CLUSTERED INDEX CIX_tmpResultHist ON #tmpResultHist (SessionID, SeqNo, MatchID, SiteDBGroupID)
		
		INSERT INTO #tmpResultHistDetail (
			SessionID
			,SeqNo
			,Transid
			,CustID
			,ExtraInfo_Before
			,ExtraInfo_After
			,IsDeleted
		)
		SELECT SessionID
			,SeqNo
			,Transid
			,CustID
			,ExtraInfo_Before
			,ExtraInfo_After
			,IsDeleted
		FROM OPENJSON((SELECT JSONData FROM #tmpJSData WHERE ObjectName = 'SettlementResultHistory_TicketDetails' AND ISJSON(JSONData) = 1)) WITH (
				SessionID VARCHAR(50) '$.SessionID'
				,SeqNo SMALLINT '$.SeqNo'
				,Transid BIGINT '$.Transid'
				,CustID INT '$.CustID'
				,ExtraInfo_Before VARCHAR(MAX) '$.ExtraInfo_Before'
				,ExtraInfo_After VARCHAR(MAX) '$.ExtraInfo_After'
				,IsDeleted BIT '$.IsDeleted'
			)--OPENJSON case-sensitive
		
		CREATE CLUSTERED INDEX CIX_tmpResultHistDetail ON #tmpResultHistDetail (SessionID, SeqNo)
		
		INSERT INTO #tmpBalanceNegativeHist (
			SessionID
			,MatchID
			,SiteDBGroupID
			,CustID
			,Site
			,Balance
			,TotalBalance
		)
		SELECT SessionID
			,MatchID
			,@SiteDBGroupID AS SiteDBGroupID
			,CustID
			,Site
			,Balance
			,TotalBalance
		FROM OPENJSON((SELECT JSONData FROM #tmpJSData WHERE ObjectName = 'BalanceNegativeHistory' AND ISJSON(JSONData) = 1)) WITH (
				SessionID VARCHAR(50) '$.SessionID'
				,MatchID INT '$.MatchID'
				,CustID INT '$.CustID'
				,Site VARCHAR(50) '$.Site'
				,Balance MONEY '$.Balance'
				,TotalBalance MONEY '$.TotalBalance'
			)--OPENJSON case-sensitive
		
		CREATE CLUSTERED INDEX CIX_tmpBalanceNegativeHist ON #tmpBalanceNegativeHist (SessionID, MatchID, SiteDBGroupID, CustID)
	
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
			,COMPRESS(@ErrLogPrefix + 'FAILED to Parse JSON Data'
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
		---For change source status from [failed] to [completed]
		IF EXISTS (
			SELECT 1
			FROM #tmpResultHist AS rh
				LEFT JOIN SettlementResultHist AS tgt
					ON rh.SessionID = tgt.SessionID
						AND rh.MatchID = tgt.MatchID
						AND rh.SeqNo = tgt.SeqNo
						AND rh.SiteDBGroupID = tgt.SiteDBGroupID
			WHERE rh.SettlementStatusID = 2
				AND tgt.StatusID = @StsRetrvFailed
				AND (
					@IsTestFlag IS NULL
					OR tgt.IsTest = @IsTestFlag
				)
		)
		BEGIN
			UPDATE tgt
			SET tgt.StatusID = @StsRetrieving
				,tgt.ActualResult = rh.ActualResult
				,tgt.WrongResult = rh.WrongResult
				,tgt.ActionType = rh.ActionType
				,tgt.ResultType = rh.ResultType
				,tgt.SportType = rh.SportType
				,tgt.CreatedTime = rh.CreatedTime
				,tgt.ExtraInfo = rh.ExtraInfo
				,tgt.IsDeleted = rh.IsDeleted
				,tgt.InsertedTime = @CurrTime --reset InsertedTime
				,tgt.LastModifiedTime = @CurrTime
			OUTPUT INSERTED.SettlementLogID
				,INSERTED.SessionID
				,INSERTED.SeqNo
				,'Change Source Status'
			INTO #tmpInsertedRH (
				SettlementLogID
				,SessionID
				,SeqNo
				,ActionDesc
			) --Get Updated SettlementLogID
			FROM SettlementResultHist AS tgt WITH (ROWLOCK,UPDLOCK)
				LEFT JOIN #tmpResultHist AS rh
					ON rh.SessionID = tgt.SessionID
						AND rh.MatchID = tgt.MatchID
						AND rh.SeqNo = tgt.SeqNo
						AND rh.SiteDBGroupID = tgt.SiteDBGroupID
			WHERE rh.SettlementStatusID = 2
				AND tgt.StatusID = @StsRetrvFailed
				AND (
					@IsTestFlag IS NULL
					OR tgt.IsTest = @IsTestFlag
				)
			
			--wirte log
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT i.SettlementLogID
				,@LogActionID
				,@LogUserID
				,COMPRESS(@InfLogPrefix + 'UPDATED SettlementResultHist with Status from [' + ISNULL(f.Status,'NULL') + '] to [' + ISNULL(r.Status,'NULL') + ']')
			FROM #tmpInsertedRH AS i
				LEFT JOIN NotiStatus AS f WITH (NOLOCK) ON f.StatusID = @StsRetrvFailed
				LEFT JOIN NotiStatus AS r WITH (NOLOCK) ON r.StatusID = @StsRetrieving
			WHERE i.ActionDesc = 'Change Source Status'
			ORDER BY i.SettlementLogID
		END
		
		---For new from source
		IF EXISTS (
			SELECT 1
			FROM #tmpResultHist AS rh
			WHERE NOT EXISTS (
					SELECT 1
					FROM SettlementResultHist AS tgt
					WHERE rh.SessionID = tgt.SessionID
						AND rh.MatchID = tgt.MatchID
						AND rh.SeqNo = tgt.SeqNo
						AND rh.SiteDBGroupID = tgt.SiteDBGroupID
				) --UNIQUE KEY (SessionID,MatchID,SeqNo,SiteDBGroupID)
		)
		BEGIN
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
				,IsDeleted
				,InsertedTime
			)
			OUTPUT INSERTED.SettlementLogID
				,INSERTED.SessionID
				,INSERTED.SeqNo
				,(CASE WHEN INSERTED.StatusID = @StsRetrieving THEN 'new completed' ELSE 'new failed' END)
			INTO #tmpInsertedRH (
				SettlementLogID
				,SessionID
				,SeqNo
				,ActionDesc
			) --Get Inserted SettlementLogID
			SELECT (CASE WHEN rh.SettlementStatusID = 2 THEN @StsRetrieving ELSE @StsRetrvFailed END) AS StatusID
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
				,IsDeleted
				,@CurrTime AS InsertedTime
			FROM #tmpResultHist AS rh
			WHERE NOT EXISTS (
					SELECT 1
					FROM SettlementResultHist AS tgt
					WHERE rh.SessionID = tgt.SessionID
						AND rh.MatchID = tgt.MatchID
						AND rh.SeqNo = tgt.SeqNo
						AND rh.SiteDBGroupID = tgt.SiteDBGroupID
				) --UNIQUE KEY (SessionID,MatchID,SeqNo,SiteDBGroupID)
			ORDER BY CreatedTime
				,SessionID
				,SeqNo
			
			--write log
			IF EXISTS (SELECT 1 FROM #tmpInsertedRH)
			BEGIN
				;WITH CTE_Status AS (
					SELECT i.SettlementLogID
						,(CASE WHEN i.ActionDesc = 'new completed' THEN r.Status ELSE f.Status + ' - Due to SrcSts(' + CONVERT(VARCHAR,rh.SettlementStatusID) + ')' END) AS Sts
					FROM #tmpInsertedRH AS i
						LEFT JOIN NotiStatus AS f WITH (NOLOCK) ON f.StatusID = @StsRetrvFailed
						LEFT JOIN #tmpResultHist AS rh ON rh.SessionID = i.SessionID AND rh.SeqNo = i.SeqNo
						LEFT JOIN NotiStatus AS r WITH (NOLOCK) ON r.StatusID = @StsRetrieving
					WHERE i.ActionDesc IN ('new completed', 'new failed')
				)
				INSERT INTO UserLog (
					RefID
					,ActionID
					,UserID
					,LogBef
				)
				SELECT i.SettlementLogID
					,@LogActionID
					,@LogUserID
					,COMPRESS(@InfLogPrefix + 'INSERTED SettlementResultHist with Status [' + ISNULL(i.Sts,'NULL') + ']')
				FROM CTE_Status AS i
				ORDER BY i.SettlementLogID
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
					,COMPRESS(@InfLogPrefix + 'Debug - NO ROW inserted SettlementResultHist')
				WHERE @LogMode = 'Debug'
			END
		END
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
			,COMPRESS(@ErrLogPrefix + 'FAILED INSERT INTO SettlementResultHist'
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
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpInsertedRH)
	BEGIN TRY
		--Can be RESTORE for exception  
		BEGIN TRANSACTION
		
			--Clear old data
			DELETE rhd
			FROM SettlementResultHistDetail AS rhd
				INNER JOIN #tmpInsertedRH AS i ON rhd.SettlementLogID = i.SettlementLogID
			
			--Insert new
			INSERT INTO SettlementResultHistDetail (
				SettlementLogID
				,Transid
				,CustID
				,ExtraInfo_Before
				,ExtraInfo_After
				,IsDeleted
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
				,rhd.IsDeleted
			FROM #tmpInsertedRH AS rh
				INNER JOIN #tmpResultHistDetail AS rhd ON rh.SessionID = rhd.SessionID AND rh.SeqNo = rhd.SeqNo
			WHERE NOT EXISTS (
					SELECT 1
					FROM SettlementResultHistDetail AS tgt
					WHERE rh.SettlementLogID = tgt.SettlementLogID
						AND rhd.Transid = tgt.Transid
						AND rhd.CustID = tgt.CustID
				)
		
		COMMIT TRANSACTION
		
		--write log
		;WITH CTE_InsertedDetail AS (
			SELECT s.SettlementLogID
				,CONVERT(NVARCHAR(MAX),(
								SELECT t.TransID
									,t.CustID
									,t.ExtraInfo_Before
									,t.ExtraInfo_After
									,t.IsDeleted
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
		
		ROLLBACK TRANSACTION
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'FAILED INSERT INTO SettlementResultHistDetail'
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
		
		--mark Failed
		UPDATE sh
		SET sh.StatusID = @StsRetrvFailed
			,sh.LastModifiedTime = @CurrTime
		FROM SettlementResultHist AS sh
			INNER JOIN #tmpInsertedRH AS rh ON sh.SettlementLogID = rh.SettlementLogID
		WHERE sh.StatusID = @StsRetrieving
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT SettlementLogID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'UPDATED recent [SettlementResultHist] inserts with Status from [Retrieving] to [Failed to Retrieve] - Due to insert [SettlementResultHistDetail] issue')
		FROM #tmpInsertedRH
		ORDER BY SettlementLogID
		
	END CATCH
	
	/*
		**************************************************Start to insert BalanceNegativeHist**************************************************
		+ For new SettlementLogID
	*/
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpInsertedRH)
	BEGIN TRY
		/*
			Currently, BalanceNegativeHistory mapped by SessionID
			
			BUT SettlementResultHistory break SessionID / SeqNo
			
			Paid Attention when handling SessionID / CustID
		*/
		
		--Can be RESTORE for exception  
		BEGIN TRANSACTION
			--Clear old data
			DELETE bn
			FROM BalanceNegativeHist AS bn
			WHERE EXISTS (
				SELECT 1
				FROM #tmpInsertedRH AS irh
					INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON rh.SettlementLogID = irh.SettlementLogID
				WHERE irh.SessionID = bn.SessionID
					AND rh.MatchID = bn.MatchID
					AND rh.SiteDBGroupID = bn.SiteDBGroupID
			)
			
			--Insert new
			INSERT INTO BalanceNegativeHist (
				SessionID
				,MatchID
				,SiteDBGroupID
				,CustID
				,Site
				,Balance
				,TotalBalance
			)
			OUTPUT INSERTED.SessionID
				,INSERTED.MatchID
				,INSERTED.SiteDBGroupID
				,INSERTED.CustID
			INTO #tmpInsertedNB (
				SessionID
				,MatchID
				,SiteDBGroupID
				,CustID
			) --Get Inserted Negative
			SELECT DISTINCT bn.SessionID
				,bn.MatchID
				,bn.SiteDBGroupID
				,bn.CustID
				,bn.Site
				,bn.Balance
				,bn.TotalBalance
			FROM #tmpBalanceNegativeHist AS bn
				INNER JOIN #tmpInsertedRH AS irh ON irh.SessionID = bn.SessionID
				INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON rh.SettlementLogID = irh.SettlementLogID AND rh.MatchID = bn.MatchID AND rh.SiteDBGroupID = bn.SiteDBGroupID
				INNER JOIN #tmpInsertedRHDetail AS rhd ON rhd.SettlementLogID = irh.SettlementLogID AND rhd.CustID = bn.CustID
			WHERE NOT EXISTS (
					SELECT 1
					FROM BalanceNegativeHist AS tgt
					WHERE bn.SessionID = tgt.SessionID
						AND bn.MatchID = tgt.MatchID
						AND bn.CustID = tgt.CustID
						AND bn.SiteDBGroupID = tgt.SiteDBGroupID
				)
		
		COMMIT TRANSACTION
		
		--write log
		;WITH CTE_InsertedNB AS (
			SELECT s.SessionID
				,CONVERT(NVARCHAR(MAX),(
								SELECT DISTINCT t.*
								FROM #tmpInsertedNB AS t
								WHERE t.SessionID = s.SessionID
								ORDER BY CustID
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
		
		ROLLBACK TRANSACTION
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'FAILED INSERT INTO BalanceNegativeHist'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - @JSSettlResultHist (' + ISNULL(@JSSettlResultHist,'NULL') + ')'
							+ ' - Prepared data('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT *
										FROM #tmpBalanceNegativeHist
										FOR JSON PATH
									))
								),'NO ROW') + ')'
							+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		--mark Failed
		UPDATE sh
		SET sh.StatusID = @StsRetrvFailed
			,sh.LastModifiedTime = @CurrTime
		FROM SettlementResultHist AS sh
			INNER JOIN #tmpInsertedRH AS rh ON sh.SettlementLogID = rh.SettlementLogID
		WHERE sh.StatusID = @StsRetrieving
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT SettlementLogID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'UPDATED recent [SettlementResultHist] inserts with Status from [Retrieving] to [Failed to Retrieve] - Due to insert [BalanceNegativeHist] issue')
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
			;WITH CTE_Session_DBCnt AS (
				SELECT sh.SessionID
					,sh.MatchID
					,sh.SeqNo
					,COUNT(DISTINCT sh.SiteDBGroupID) AS SiteDBCnt
				FROM #tmpResultHist AS rh
					INNER JOIN SettlementResultHist AS sh ON rh.SessionID = sh.SessionID --case SettlementStatusID=2
				WHERE @IsTestFlag IS NULL
					OR sh.IsTest = @IsTestFlag
				GROUP BY sh.SessionID
					,sh.MatchID
					,sh.SeqNo
			)
			UPDATE sh
			SET sh.StatusID = @StsRetrieved
				,sh.LastModifiedTime = @CurrTime
			OUTPUT INSERTED.SettlementLogID
				,'Full SiteDBGroupIDs'
			INTO @tmpUpdatedRH (SettlementLogID, UpdatedCase)
			FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
				INNER JOIN CTE_Session_DBCnt AS s ON sh.SessionID = s.SessionID AND sh.MatchID = s.MatchID AND sh.SeqNo = s.SeqNo
			WHERE s.SiteDBCnt = @SiteDBCnt
				AND sh.StatusID = @StsRetrieving
				AND (
					@IsTestFlag IS NULL
					OR sh.IsTest = @IsTestFlag
				)
			
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
					,MatchID
					,SeqNo
				FROM SettlementResultHist
				WHERE StatusID = @StsRetrieving
					AND LastModifiedTime >= DATEADD(HH, - 36, @CurrTime) --use NONCLUSTERED
				GROUP BY SessionID
					,MatchID
					,SeqNo
				HAVING DATEDIFF(SECOND, MIN(InsertedTime),@CurrTime) > @Retrieving_WaitSec
			)
			UPDATE sh
			SET sh.StatusID = @StsRetrieved
				,sh.LastModifiedTime = @CurrTime
			OUTPUT INSERTED.SettlementLogID
				,'Over Retrieving_WaitSec'
			INTO @tmpUpdatedRH (SettlementLogID, UpdatedCase)
			FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
				INNER JOIN CTE_Session_INSTime AS s ON sh.SessionID = s.SessionID AND sh.MatchID = s.MatchID AND sh.SeqNo = s.SeqNo
			WHERE sh.StatusID = @StsRetrieving
				AND (
					@IsTestFlag IS NULL
					OR sh.IsTest = @IsTestFlag
				)
			
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
			,COMPRESS(@ErrLogPrefix + 'FAILED UPDATE SettlementResultHist.Status'
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
		,COMPRESS(@InfLogPrefix + 'Completed - @SiteDBGroupID(' + ISNULL(CONVERT(VARCHAR,@SiteDBGroupID),'NULL') + ')'
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
		,COMPRESS(@InfLogPrefix + 'Debug - Completed'
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
	
	/*
		Handle LastSessionID & LastRunTime
	*/
	DECLARE @LastSessionID VARCHAR(50)
		,@LastRunTime DATETIME
	
	;WITH CTE_Last AS (
		SELECT TOP 1 rh.SessionID
			,ISNULL(rh.LastModifiedTime,@CurrTime) AS LastModifiedTime
		FROM #tmpInsertedRH AS i
			INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON i.SettlementLogID = rh.SettlementLogID
		ORDER BY ISNULL(rh.LastModifiedTime,@CurrTime) DESC
			,rh.SessionID DESC
	)
	SELECT @LastSessionID = SessionID
		,@LastRunTime = LastModifiedTime
	FROM CTE_Last
	
	IF @LastRunTime IS NOT NULL
	BEGIN
		IF @Environment = 'LIVE'
		BEGIN
			UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
			SET VValue = @LastSessionID
			WHERE VID = 15 --LastSessionID
			
			UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
			SET VValue = CONVERT(VARCHAR, @LastRunTime, 120)
			WHERE VID = 18 --LastRunTime
		END
		ELSE
		BEGIN
			UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
			SET VValue = @LastSessionID
			WHERE VID = 19 --UAT_LastSessionID
			
			UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
			SET VValue = CONVERT(VARCHAR, @LastRunTime, 120)
			WHERE VID = 20 --UAT_LastRunTime
		END
	END
	
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Debug - UPDATE LastSessionID/LastRunTime'
					+ ' - @LastRunTime(' + ISNULL(CONVERT(VARCHAR, @LastRunTime),'NULL') + ')'
					+ ' - @LastSessionID(' + ISNULL(@LastSessionID,'NULL') + ')'
		)
	WHERE @LogMode = 'Debug'
	
	DROP TABLE #tmpJSData
	DROP TABLE #tmpResultHist
	DROP TABLE #tmpInsertedRH
	DROP TABLE #tmpResultHistDetail
	DROP TABLE #tmpInsertedRHDetail
	DROP TABLE #tmpBalanceNegativeHist
	DROP TABLE #tmpInsertedNB
END
