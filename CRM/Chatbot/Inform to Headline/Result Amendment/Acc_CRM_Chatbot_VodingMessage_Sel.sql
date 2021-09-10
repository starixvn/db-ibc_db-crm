/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_Chatbot_VodingMessage_Sel]
	@BatchSizeGetMsg INT = 10
AS
/*
Created: 20210811@Malcolm
Task :  Get message
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20210811@Malcolm: Initialize SPs [Redmine: #151509]
	Param's Explanation:

		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Message TABLE (MessageId INT PRIMARY KEY)
	
	INSERT INTO @Message (MessageId)
	SELECT DISTINCT TOP(@BatchSizeGetMsg) m.MessageId
	FROM dbo.crmVoidingMessage m WITH(NOLOCK)
	WHERE m.IsChatBotProcessed = 0
	ORDER BY m.MessageId ASC

	CREATE TABLE #TargetMessage (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX))
	INSERT INTO #TargetMessage (MessageId, MsgTargetId, BetTransId)
	SELECT vm.MessageId, vm.MsgTargetId, vm.BetTransId
	FROM dbo.crmVoidingMessage vm WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM @Message m WHERE m.MessageId = vm.MessageId) AND vm.IsChatBotProcessed = 0 

	CREATE TABLE #InfoMessage (MessageId INT, TransId BIGINT, CustId INT, Username VARCHAR(30), Recommend INT, Mrecommend INT, Srecommend INT, IsTest BIT)

	INSERT INTO #InfoMessage (MessageId, TransId)
	SELECT vm.MessageId, t.TransId
	FROM #TargetMessage vm WITH(NOLOCK)
		CROSS APPLY (SELECT RTRIM(LTRIM(f.val)) AS TransId FROM f_CRM_strSplit(vm.BetTransId, ',') f WHERE f.val <> '') t
	
	CREATE INDEX ix_TransId ON #InfoMessage (TransId)

	UPDATE t
		SET t.CustId = n.custid, t.Username = n.Username, t.Recommend = n.Recommend, t.Mrecommend = n.mrecommend, t.Srecommend = n.Srecommend, t.IsTest = n.IsTest
	FROM #InfoMessage t
		CROSS APPLY (
				SELECT b.CustId, b.Username, b.Recommend, b.Mrecommend, b.Srecommend, CASE WHEN b.currency IN (20, 72) THEN 1 ELSE 0 END AS IsTest
				FROM bodb02.dbo.bettrans b WITH(NOLOCK)
				WHERE b.transid = t.TransId
		) AS n

	UPDATE t
		SET t.CustId = n.custid, t.Username = n.Username, t.Recommend = n.Recommend, t.Mrecommend = n.mrecommend, t.Srecommend = n.Srecommend, t.IsTest = n.IsTest
	FROM #InfoMessage t
		CROSS APPLY (
				SELECT b.CustId, b.Username, b.Recommend, b.Mrecommend, b.Srecommend, CASE WHEN b.currency IN (20, 72) THEN 1 ELSE 0 END AS IsTest
				FROM bodb02.dbo.bettrans14 b WITH(NOLOCK)
				WHERE b.transid = t.TransId
		) AS n
	WHERE t.CustId IS NULL

	SELECT MessageId FROM @Message

	SELECT MessageId, MsgTargetId, 6 AS [Type] FROM #TargetMessage

	SELECT DISTINCT MessageId, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest FROM #InfoMessage

	DROP TABLE #InfoMessage
END
GO

