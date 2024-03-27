/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Alert_Ins
	@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Insert Alert based on AlertRule
	DB: DBMSG.bodb_Message
	Revisions:
		20230515@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:

		Output
			@ErrCode
			@ErrMsg
	
	Example:
		EXEC bodb_Message.dbo.MNC_Alert_Ins
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StsNew TINYINT
		,@RuleID INT
		,@ITRuleID INT = 1 --this RuleID config to receive all message
		,@SQLStatement NVARCHAR(MAX)
		,@JSAlertResult NVARCHAR(MAX)
		,@Params NVARCHAR(1000) = N'@JSAlertResult NVARCHAR(4000) OUTPUT'
	
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
	WHERE RuleID <> @ITRuleID
	
	WHILE EXISTS (SELECT 1 FROM AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID)
	BEGIN TRY
		
		SELECT @SQLStatement = SQLStatement
			,@JSAlertResult = ''
		FROM AlertRule WITH (NOLOCK)
		WHERE RuleID = @RuleID
		
		EXEC sp_executesql @SQLStatement, @Params, @JSAlertResult = @JSAlertResult OUTPUT
		
		;WITH CTE_Rule AS (
			SELECT @RuleID AS RuleID
			UNION
			SELECT @ITRuleID AS RuleID
		)
		INSERT INTO Alert (
			StatusID
			,RuleID
			,RefID
			,Content
		)
		SELECT DISTINCT @StsNew AS StatusID
			,r.RuleID
			,rs.RefID
			,rs.Content
		FROM OPENJSON(@JSAlertResult) WITH (
				RefID NVARCHAR(MAX) '$.RefID' --list of SettlementLogID / NotificationID
				,Content NVARCHAR(MAX) '$.Content'
			) AS rs --OPENJSON case-sensitive
			,CTE_Rule AS r
		WHERE ISNULL(TRIM(rs.Content),'') <> ''
		ORDER BY rs.RefID
			,r.RuleID
		
		SELECT @RuleID = (SELECT MIN(RuleID) FROM AlertRule WITH (NOLOCK) WHERE RuleID > @RuleID AND RuleID <> @ITRuleID)
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @RuleID
			,@LogActionID
			,@LogUserID
			,'Error - FAILED while EXEC AlertRule = ' + ISNULL(@RuleID,'NULL')
					+ ', @SQLStatement = (' + ISNULL(@SQLStatement,'NULL') + ')'
					+ ', ERROR_MESSAGE = (' + ISNULL(@ErrMsg,'NULL') + ')'
		
		--Continue exec for next RuleID
		SELECT @RuleID = (SELECT MIN(RuleID) FROM AlertRule WITH (NOLOCK) WHERE RuleID > @RuleID AND RuleID <> @ITRuleID)
	END CATCH
END
