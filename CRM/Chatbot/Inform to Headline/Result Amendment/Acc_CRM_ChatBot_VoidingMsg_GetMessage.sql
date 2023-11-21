/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_VoidingMsg_GetMessage]
	@LastMsgTargetId	INT
	,@BatchSizeGetMsg	INT
AS
/*
	Created: 20210811@Malcolm
	Task :  Get message
	DB: DBMSG/bodb_Message
	Original:
	Revisions:
		- 20210811@Malcolm: Initialize SPs [Redmine: #151509]
		- 20231017@Malcolm: Get message for refund settled ticket [Redmine: #195404]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MaxMsgTargetId INT

	SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)

	WAITFOR DELAY '00:00:04'

	DECLARE @Msg TABLE (MessageId INT PRIMARY KEY, MsgContentsType TINYINT, MsgTargetId INT, MaxMsgTargetId INT, MatchId INT)

	/*
		MsgContentsType = 102 : Void Setted tickets
		MsgContentsType = 110 : refund settled ticket
	*/
	INSERT INTO @Msg (MessageId, MsgContentsType, MsgTargetId, MatchId)
	SELECT m.MessageId, m.MsgContentsType, MIN(mt.MsgTargetId) AS MsgTargetId, m.MatchId
	FROM dbo.MsgTarget mt WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP(2147483647) m.MessageId, m.MsgContentsType, m.MatchId
			FROM dbo.Msg m WITH(NOLOCK) 
			WHERE m.MessageId = mt.MessageId AND (m.MsgContentsType = 102 OR m.MsgContentsType = 110 AND m.MsgType = 1)
		) AS m
	WHERE  mt.MsgTargetId > @LastMsgTargetId AND mt.MsgTargetId <= @MaxMsgTargetId
	GROUP BY m.MessageId, m.MsgContentsType, m.MatchId

	;WITH CTE_MsgTarget AS
	(
		SELECT MsgTargetId - 1 AS MaxMsgTargetId
		FROM (
			SELECT MessageId, MsgTargetId, COUNT(1) OVER(ORDER BY MsgTargetId) AS NoOfMessage
			FROM @Msg
		) AS t
		WHERE NoOfMessage = @BatchSizeGetMsg + 1
	)
	SELECT @MaxMsgTargetId = MaxMsgTargetId
	FROM CTE_MsgTarget
	
	DECLARE @Result TABLE (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX), MsgContentsType TINYINT, MatchId INT)

	INSERT INTO @Result (MessageId, MsgTargetId, BetTransId, MsgContentsType, MatchId)
	SELECT t.MessageId, t.MsgTargetId, t.BetTransId, m.MsgContentsType, m.MatchId
	FROM dbo.MsgTarget t WITH(NOLOCK) 
		INNER JOIN @Msg m ON m.MessageId = t.MessageId
	WHERE t.MsgTargetId <= @MaxMsgTargetId AND t.MsgTargetId > @LastMsgTargetId
	ORDER BY t.MsgTargetId ASC

	SELECT MessageId, MsgTargetId, BetTransId, MsgContentsType, MatchId 
	FROM @Result 
	WHERE MsgContentsType = 110 
	ORDER BY MsgTargetId ASC

	SELECT MessageId, MsgTargetId, BetTransId, MsgContentsType, MatchId 
	FROM @Result 
	WHERE MsgContentsType = 102 
	ORDER BY MsgTargetId ASC

END
GO



