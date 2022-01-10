/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_VodingMessage_Check]
	@Message XML
	,@Environment VARCHAR(50) = ''
AS
/*
Created: 20211105@Malcolm
Task : Check message
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20211105@Malcolm: Initialize SPs [Redmine: #164235]
		- 20220110@Malcolm: Include @Environment parameter [Redmine: #164235]
	Param's Explanation:
	 @Message:
			<root>
				<r MessageId="1" MsgTargetId="" BetTransId=""/>
			</root>
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TmpMessage (MessageId INT, MsgTargetId INT, TransId BIGINT, IsTest BIT)
	CREATE TABLE #Message (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX))

	DECLARE @IncludeUUSCurrency BIT
	
	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM SystemSetting WITH(NOLOCK) WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName = 'IncludeUUSCurrency'

	INSERT INTO #TmpMessage (MessageId, MsgTargetId, TransId)
	SELECT 
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,n.TransId
	FROM @Message.nodes('root/r') t(c)
	CROSS APPLY (
		SELECT f.val AS TransId
		FROM dbo.f_CRM_strSplit(t.c.value('@BetTransId','VARCHAR(MAX)'), ',') AS f
	) AS n
	OPTION (OPTIMIZE FOR (@Message = NULL))

	-- Get data based on environment variable
	BEGIN
		UPDATE m
			SET m.IsTest = n.IsTest
		FROM #TmpMessage m
		CROSS APPLY (
			SELECT TOP(1) CASE WHEN currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE b.transid = m.TransId
		) as n(IsTest)

		UPDATE m
			SET m.IsTest = n.IsTest
		FROM #TmpMessage m
		CROSS APPLY (
			SELECT TOP(1) CASE WHEN currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM bodb02.dbo.bettrans14 b WITH(NOLOCK)
			WHERE b.transid = m.TransId
		) as n(IsTest)
		WHERE m.IsTest IS NULL

		CREATE INDEX ix_TmpMessage ON #TmpMessage (MessageId, MsgTargetId)

		;WITH CTE AS
		(
			SELECT m.MessageId, MIN(CONVERT(TINYINT, m.IsTest)) AS IsTest
			FROM #TmpMessage m
			GROUP BY m.MessageId
		)
		DELETE m
		FROM #TmpMessage m
			INNER JOIN CTE e ON e.MessageId = m.MessageId
		WHERE @Environment = 'UAT' AND e.IsTest = 0
			OR (@Environment <> 'UAT' AND @IncludeUUSCurrency = 0 AND e.IsTest = 1)
	END

	;WITH CTE AS
	(
		SELECT MessageId, MsgTargetId
		FROM #TmpMessage
		GROUP BY MessageId, MsgTargetId
	)
	INSERT INTO #Message (MessageId, MsgTargetId, BetTransId)
	SELECT 
		e.MessageId
		,e.MsgTargetId
		,STUFF((SELECT ',' + CONVERT(VARCHAR(50), TransId) FROM #TmpMessage m WHERE m.MessageId = e.MessageId AND m.MsgTargetId = e.MsgTargetId FOR XML PATH('')), 1, 1, '') AS BetTransId
	FROM CTE e 
	OPTION (MAXRECURSION 0)

	SELECT m.MessageId, m.MsgTargetId, m.BetTransId
	FROM #Message m 
	WHERE NOT EXISTS (SELECT 1 FROM dbo.crmVoidingMessage vm WITH(NOLOCK) WHERE vm.MessageId = m.MessageId AND vm.MsgTargetId = m.MsgTargetId)

	DROP TABLE #Message
	DROP TABLE #TmpMessage
END
GO

