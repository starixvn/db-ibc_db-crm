/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_VodingMessage_Sel]
	@BatchSize INT = 10
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
	SELECT DISTINCT TOP(@BatchSize) m.MessageId
	FROM dbo.crmVoidingMessage m WITH(NOLOCK)
	WHERE m.IsChatBotProcessed = 0

	CREATE TABLE #TargetMessage (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX))
	SELECT vm.MessageId, vm.MsgTargetId, vm.BetTransId
	FROM dbo.crmVoidingMessage vm WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM @Message m WHERE m.MessageId = vm.MessageId) AND vm.IsChatBotProcessed = 0 

	CREATE TABLE #InfoMessage (MessageId INT, CustId INT, Username VARCHAR(30), Recommend INT, Mrecommend INT, Srecommend INT, IsTest BIT)

	INSERT INTO #InfoMessage (MessageId, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest)
	SELECT vm.MessageId, n.custid, n.Username, n.recommend, n.mrecommend, n.srecommend, n.IsTest
	FROM #TargetMessage vm WITH(NOLOCK)
		CROSS APPLY (SELECT f.val AS TransId FROM f_CRM_strSplit(vm.BetTransId, '') f WHERE f.val <> '') t
		CROSS APPLY (
			SELECT b.CustId, b.Username, b.recommend, b.mrecommend, b.srecommend, CASE WHEN b.currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE b.transid = t.TransId
		) AS n

	INSERT INTO #InfoMessage (MessageId, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest)
	SELECT vm.MessageId, n.custid, n.Username, n.recommend, n.mrecommend, n.srecommend, n.IsTest
	FROM #TargetMessage vm WITH(NOLOCK)
		CROSS APPLY (SELECT f.val AS TransId FROM f_CRM_strSplit(vm.BetTransId, '') f WHERE f.val <> '') t
		CROSS APPLY (
			SELECT b.CustId, b.Username, b.recommend, b.mrecommend, b.srecommend, CASE WHEN b.currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM bodb02.dbo.bettrans14 b WITH(NOLOCK)
			WHERE b.transid = t.TransId
		) AS n

	SELECT MessageId FROM @Message

	SELECT MessageId, MsgTargetId FROM #TargetMessage

	SELECT DISTINCT MessageId, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest, 6 AS [Type] FROM #InfoMessage

	DROP TABLE #InfoMessage
END
GO

