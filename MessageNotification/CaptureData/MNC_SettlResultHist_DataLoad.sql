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
				+ The UNIQUE KEY of SettlementResultHist (SessionID,MatchID,SeqNo,Environment)
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
		,@ProcessID INT
		,@UATMode VARCHAR(5) = 'OFF'
		,@IsTestFlag BIT
		,@StsRetrieving TINYINT
		,@StsRetrieved TINYINT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		-- ,@RHE_Msg NVARCHAR(MAX)
		-- ,@IsError BIT = 0
	
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
	
	-- SELECT @StsRetrieveFailed = StatusID
	-- FROM NotiStatus WITH (NOLOCK)
	-- WHERE Status = 'Failed to Retrieve'
	
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
		SELECT @ErrCode = 1
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
	ELSE IF @UATMode = 'ON' AND @Environment = 'LIVE' --REAL data only
	BEGIN
		SET @IsTestFlag = 0
	END
	ELSE IF @UATMode = 'ON' AND @Environment = 'UAT' --TEST data only
	BEGIN
		SET @IsTestFlag = 1
	END
	ELSE --both REAL & TEST
	BEGIN
		SET @IsTestFlag = NULL
	END
	
	--write more info if LogMode = Debug
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Start Data loading with @UATMode = ' + @UATMode + ', @JSSettlResultHist('+ISNULL(@JSSettlResultHist,'NULL')+')'
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
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
		SELECT SiteDBGroupID
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
				SiteDBGroupID SMALLINT '$.SiteDBGroupID'
				,SessionID VARCHAR(50) '$.SessionID'
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
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'FAILED to Parse JSON Data - ERROR_MESSAGE('
								+ ISNULL(@ErrMsg,'NULL')
								+ ') with @JSSettlResultHist = ('
								+ ISNULL(@JSSettlResultHist,'NULL')
								+ ')'
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
			INSERT INTO [Log] (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT SettlementLogID
				,@LogActionID
				,@LogUserID
				,@InfLogPrefix + 'INSERTED SettlementResultHist with StatusID(' + ISNULL(Status,'NULL') + ')'
			FROM #tmpInsertedRH AS i
				LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON s.StatusID = @StsRetrieving
			ORDER BY SettlementLogID
		ELSE
			INSERT INTO [Log] (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,@InfLogPrefix + 'NO ROW inserted SettlementResultHist'
			FROM SystemSetting WITH (NOLOCK)
			WHERE VID = 13 --LogMode
				AND VValue = 'Debug'
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'FAILED INSERT INTO SettlementResultHist - ERROR_MESSAGE('
								+ ISNULL(@ErrCode,'NULL')
								+ '); tmp data ('
								+ ( SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpResultHist
											FOR JSON AUTO
										))
									)
								+ ')'
		
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
								SELECT TransID
									,CustID
									,ExtraInfo_Before
									,ExtraInfo_After
								FROM SettlementResultHistDetail AS t
								WHERE t.Transid = s.Transid
									AND t.CustID = s.CustID
								ORDER BY TransID
								FOR JSON AUTO
							)) AS LTxt
			FROM #tmpInsertedRHDetail AS s
		)
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT rh.SettlementLogID
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + 'INSERTED SettlementResultHistDetail (' + ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX),d.LTxt),','),'NO ROW')+ ')'
		FROM #tmpInsertedRH AS rh
			LEFT JOIN CTE_InsertedDetail AS d ON rh.SettlementLogID = d.SettlementLogID
		GROUP BY rh.SettlementLogID
		ORDER BY rh.SettlementLogID
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'FAILED INSERT INTO SettlementResultHistDetail - ERROR_MESSAGE('
								+ ISNULL(@ErrCode,'NULL')
								+ '); tmp data ('
								+ ( SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpResultHistDetail
											FOR JSON AUTO
										))
									)
								+ ')'
		
		--Remove Inserted SettlementLogID
		DELETE sh
		FROM SettlementResultHist AS sh
			INNER JOIN #tmpInsertedRH AS rh ON sh.SettlementLogID = rh.SettlementLogID
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT SettlementLogID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Removed due to Failed insert SettlementResultHistDetail'
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
			,@Retrieving_WaitSec INT = 0
		
		SELECT @SiteDBCnt = COUNT(DISTINCT SiteDBGroupID)
		FROM bodb02.dbo.SiteDBConfig WITH (NOLOCK)
		WHERE SiteDBGroupID <> 0
		
		SELECT @Retrieving_WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0)
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 11 --Retrieving_WaitSec
		
		BEGIN TRANSACTION --lock Retrieving SettlementResultHist for UPD Status
			
			/*
				Update for CASE #1
					Count of SiteDBGroupID By [SessionID] = Count of SiteDBConfig (UPD only for StatusID = Retrieving)
			*/
			TRUNCATE TABLE #tmpInsertedRH
			
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
			INTO #tmpInsertedRH (SettlementLogID)
			FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
				INNER JOIN CTE_Sts AS sts ON sh.SessionID = sts.SessionID AND sh.MatchID = sts.MatchID AND sh.SeqNo = sts.SeqNo
			WHERE sts.SiteDBCnt = @SiteDBCnt
				AND sh.StatusID = @StsRetrieving
			
			--write log
			INSERT INTO [Log] (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT i.SettlementLogID
				,@LogActionID
				,@LogUserID
				,@InfLogPrefix + 'Changed Status from [Retrieving] to [Successfully Retrieved] (All data from SiteDBConfig.SiteDBGroupIDs is loaded)'
			FROM #tmpInsertedRH AS i
			ORDER BY i.SettlementLogID
			
			/*
				Update for CASE #1
					SessionID inserted too long (over configuration time in SystemSetting)
			*/
			TRUNCATE TABLE #tmpInsertedRH
			
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
			INTO #tmpInsertedRH (SettlementLogID)
			FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
				INNER JOIN CTE_Session_INSTime AS s ON sh.SessionID = s.SessionID
			WHERE sh.StatusID = @StsRetrieving
			
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
				,@InfLogPrefix + 'Changed Status from [Retrieving] to [Successfully Retrieved] - Over Retrieving_WaitSec(' + ISNULL(CONVERT(VARCHAR,@Retrieving_WaitSec),'') +') configuration'
			FROM #tmpInsertedRH AS rh
			ORDER BY SettlementLogID
	
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		ROLLBACK TRANSACTION
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'FAILED UPDATE SettlementResultHist.Status - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')'
	END CATCH
	
	/**************************************************Mark Capture process DONE**************************************************/
	UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
	SET VValue = 'Done'
	WHERE VID = @ProcessID
		AND VValue = 'Running'
	
	----------------------Log to make sure system still live-----------------
	IF EXISTS (
		SELECT VValue
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 13 --LogMode
			AND VValue = 'Debug'
	)
	BEGIN
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Debug log to make sure [Capture process] still live - @JSSettlResultHist(' + ISNULL(@JSSettlResultHist,'NULL') + ')'
	END
	
	DROP TABLE #tmpJSData
	DROP TABLE #tmpResultHist
	DROP TABLE #tmpInsertedRH
	DROP TABLE #tmpResultHistDetail
	DROP TABLE #tmpInsertedRHDetail
END
