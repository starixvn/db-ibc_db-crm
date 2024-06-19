/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AlertIns
	@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Insert Alert based on AlertRule
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:

		Output
			@ErrCode
			@ErrMsg
	
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AlertIns
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogActionID TINYINT
		,@LogUserID INT
		,@StsNew TINYINT
		,@RuleID INT
		,@ITRuleID INT = 1 --this RuleID config to receive all message
		,@SQLStatement NVARCHAR(MAX)
		,@JSAlertResult NVARCHAR(MAX)
		,@Params NVARCHAR(1000) = N'@RuleID INT, @LastScan VARCHAR(500) OUTPUT, @JSAlertResult NVARCHAR(MAX) OUTPUT'
		,@LastScan VARCHAR(500)
		,@Validation INT
		,@ExcpInsCnt INT
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	----------------------------------------------
	SELECT @RuleID = MIN(RuleID)
	FROM AlertRule WITH (NOLOCK)
	
	WHILE EXISTS (SELECT 1 FROM AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID)
	BEGIN TRY
		
		--check target ChatGroupID
		IF NOT EXISTS (
			SELECT 1
			FROM AlertRule AS a WITH (NOLOCK)
				CROSS APPLY STRING_SPLIT(a.ChatGroupIDs, ',') AS i
				INNER JOIN SystemSetting AS s WITH (NOLOCK) ON TRY_CONVERT(INT,TRIM(i.value)) = s.VID
			WHERE a.RuleID = @RuleID
		)
		BEGIN
			--send error log
			INSERT INTO Alert (
				StatusID
				,RuleID
				,RefID
				,RefExtraInfo
				,Content
			)
			SELECT DISTINCT @StsNew AS StatusID
				,@RuleID AS RuleID
				,@RuleID AS RefID
				,'[{"RefInfo":"RuleID"}]' AS RefExtraInfo --RefInfo=RuleID => only send in IT ChatGroup
				,'FAILED while EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')'
					+ ' - ChatGroupIDs(' + ISNULL(a.ChatGroupIDs,'NULL') + ') may not be configured.' AS Content
			FROM AlertRule AS a WITH (NOLOCK)
			WHERE a.RuleID = @RuleID
			
			--write log
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT @RuleID
				,@LogActionID
				,@LogUserID
				,COMPRESS(N'Error - Alert - FAILED while EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')'
						+ ' - ChatGroupIDs(' + ISNULL(a.ChatGroupIDs,'NULL') + ') may not be configured.')
			FROM AlertRule AS a WITH (NOLOCK)
			WHERE a.RuleID = @RuleID
			
			--Continue exec for next RuleID
			SELECT @RuleID = (SELECT MIN(RuleID) FROM AlertRule WITH (NOLOCK) WHERE RuleID > @RuleID)
			
			CONTINUE
		END
		
		---Start EXEC Rule
		SELECT @SQLStatement = SQLStatement
			,@JSAlertResult = ''
			,@LastScan = LastScan
		FROM AlertRule WITH (NOLOCK)
		WHERE RuleID = @RuleID
		
		EXEC sp_executesql @SQLStatement, @Params
					,@RuleID = @RuleID
					,@LastScan = @LastScan OUTPUT
					,@JSAlertResult = @JSAlertResult OUTPUT
		
		INSERT INTO Alert (
			StatusID
			,RuleID
			,RefID
			,RefExtraInfo
			,Content
		)
		SELECT DISTINCT @StsNew AS StatusID
			,@RuleID AS RuleID
			,rs.RefID
			,rs.RefExtraInfo
			,rs.Content
		FROM OPENJSON(@JSAlertResult) WITH (
				RefID VARCHAR(50) '$.RefID'
				,RefExtraInfo NVARCHAR(MAX) '$.RefExtraInfo' AS JSON
				,Content NVARCHAR(4000) '$.Content'
			) AS rs --OPENJSON case-sensitive
		WHERE ISNULL(TRIM(rs.Content),'') <> ''
			AND ISJSON(@JSAlertResult) = 1
		ORDER BY rs.RefID
		
		SELECT @ExcpInsCnt = @@ROWCOUNT
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @RuleID
			,@LogActionID
			,@LogUserID
			,COMPRESS(N'Info - Alert - EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')'
					+ ' - @LastScan(' + ISNULL(@LastScan,'NULL') + ')'
					+ ' - @JSAlertResult(' + ISNULL(@JSAlertResult,'NULL') + ')')
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 13 --LogMode
			AND (VValue = 'Debug' OR (ISNULL(TRIM(@JSAlertResult),'') <> '' AND ISNULL(@LastScan,'') <> ''))
			AND @ExcpInsCnt > 0
		
		UPDATE AlertRule WITH (ROWLOCK,UPDLOCK)
		SET LastScan = @LastScan
		WHERE RuleID = @RuleID
		
		SELECT @RuleID = (SELECT MIN(RuleID) FROM AlertRule WITH (NOLOCK) WHERE RuleID > @RuleID)
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
			,@ExcpInsCnt = 0
		
		--send error log
		INSERT INTO Alert (
			StatusID
			,RuleID
			,RefID
			,RefExtraInfo
			,Content
		)
		SELECT DISTINCT @StsNew AS StatusID
			,@RuleID AS RuleID
			,@RuleID AS RefID
			,'[{"RefInfo":"RuleID"}]' AS RefExtraInfo --RefInfo=RuleID => only send in IT ChatGroup
			,'FAILED while EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')'
				+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')' AS Content
		WHERE NOT EXISTS (
			SELECT 1
			FROM Alert AS a WITH (NOLOCK)
			WHERE a.RuleID = @RuleID
				AND a.RefID = @RuleID
				AND a.Content = ('FAILED while EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')' + ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
				AND DATEADD(MI, 5, a.InsertedTime) > GETDATE() --check not Spam - insert after 5 mins
		)
		
		SELECT @ExcpInsCnt = @@ROWCOUNT
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @RuleID
			,@LogActionID
			,@LogUserID
			,COMPRESS(N'Error - Alert - FAILED while EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')'
					+ ' - @Inssert Exception Count(' + ISNULL(CONVERT(VARCHAR,@ExcpInsCnt),'NULL') + ')'
					+ ' - @SQLStatement(' + ISNULL(@SQLStatement,'NULL') + ')'
					+ ' - @Params(' + ISNULL(@Params,'NULL') + ')'
					+ ' - @LastScan(' + ISNULL(@LastScan,'NULL') + ')'
					+ ' - @JSAlertResult(' + ISNULL(@JSAlertResult,'NULL') + ')'
					+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		--Continue exec for next RuleID
		SELECT @RuleID = (SELECT MIN(RuleID) FROM AlertRule WITH (NOLOCK) WHERE RuleID > @RuleID)
	END CATCH
END
