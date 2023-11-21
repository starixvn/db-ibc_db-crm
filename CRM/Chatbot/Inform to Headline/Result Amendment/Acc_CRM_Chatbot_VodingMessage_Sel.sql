/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_Chatbot_VodingMessage_Sel]
	@Message		XML
AS
/*
	Created: 20210811@Malcolm
	Task :  Get message
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:
		- 20210811@Malcolm: Initialize SPs [Redmine: #151509]
		- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
		- 20231017@Malcolm: Add MsgContentsType, MatchId [Redmine: #195404]
		
	Param's Explanation:
	@Message:
			<root>
				<r MessageId="1" MsgTargetId="" BetTransId="" MsgContentsType="" MatchId="" />
			</root>

		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IncludeUUSCurrency BIT
	
	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName = 'IncludeUUSCurrency'
	
	CREATE TABLE #Message (MessageId INT, MsgTargetId INT, TransId BIGINT, MsgContentsType TINYINT, MatchId INT, CustId INT, Username VARCHAR(30), Recommend INT, Mrecommend INT, Srecommend INT, IsTest BIT)

	INSERT INTO #Message (MessageId, MsgTargetId, MsgContentsType, MatchId, TransId)
	SELECT DISTINCT
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,t.c.value('@MsgContentsType', 'TINYINT') AS MsgContentsType
		,t.c.value('@MatchId', 'INT') AS MatchId
		,n.TransId
	FROM @Message.nodes('root/r') t(c)
	CROSS APPLY (
		SELECT f.value AS TransId
		FROM STRING_SPLIT(t.c.value('@BetTransId','VARCHAR(MAX)'), ',') AS f
	) AS n
	OPTION (OPTIMIZE FOR (@Message = NULL))
	
	CREATE INDEX ix_TransId ON #Message (TransId)

	UPDATE t
		SET t.CustId = n.custid, t.Username = n.Username, t.Recommend = n.Recommend, t.Mrecommend = n.mrecommend, t.Srecommend = n.Srecommend, t.IsTest = n.IsTest
	FROM #Message t
		CROSS APPLY (
				SELECT b.CustId, b.Username, b.Recommend, b.Mrecommend, b.Srecommend, CASE WHEN b.currency IN (20, 72) THEN 1 ELSE 0 END AS IsTest
				FROM bodb02.dbo.bettrans b WITH(NOLOCK)
				WHERE b.transid = t.TransId
		) AS n

	UPDATE t
		SET t.CustId = n.custid, t.Username = n.Username, t.Recommend = n.Recommend, t.Mrecommend = n.mrecommend, t.Srecommend = n.Srecommend, t.IsTest = n.IsTest
	FROM #Message t
		CROSS APPLY (
				SELECT b.CustId, b.Username, b.Recommend, b.Mrecommend, b.Srecommend, CASE WHEN b.currency IN (20, 72) THEN 1 ELSE 0 END AS IsTest
				FROM bodb02.dbo.bettrans14 b WITH(NOLOCK)
				WHERE b.transid = t.TransId
		) AS n
	WHERE t.CustId IS NULL

	--If same TransId get the largest messageid
	;WITH CTE AS
	(
		SELECT m.TransId, MAX(MessageId) AS MaxMessageId
		FROM #Message m
		WHERE m.MsgContentsType = 102
		GROUP BY m.TransId
		HAVING COUNT(1) > 1
	)
	DELETE m
	FROM #Message m
		INNER JOIN CTE e ON e.TransId = m.TransId AND m.MessageId < e.MaxMessageId
	WHERE m.MsgContentsType = 102

	SELECT DISTINCT MessageId FROM #Message

	SELECT 
		MessageId
		,MsgTargetId
		,CASE WHEN MsgContentsType = 102 THEN 6
			  WHEN MsgContentsType = 110 THEN 7
		 ELSE 0 END AS [Type] 
	FROM #Message

	SELECT DISTINCT MessageId, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest FROM #Message

	DROP TABLE #Message
END
GO

