/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingMsg_GetMessage]
AS
/*
Created: 20210811@Malcolm
Task :  Get message
DB: DBMSG/bodb_Message
Original:
	Revisions:
		- 20210811@Malcolm: Initialize SPs [Redmine: #151509]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Msg TABLE (MessageId INT PRIMARY KEY)
	INSERT INTO @Msg (MessageId)
	SELECT m.MessageId
	FROM dbo.Msg m WITH(NOLOCK)
	WHERE m.MsgContentsType = 102 AND m.PostTime >= GETDATE() - 1
		AND EXISTS (SELECT 1 FROM dbo.MsgTarget t WITH(NOLOCK) WHERE t.MessageId = m.MessageId)

	WAITFOR DELAY '00:00:03.00'

	SELECT t.MessageId, t.MsgTargetId, t.BetTransId
	FROM dbo.MsgTarget t WITH(NOLOCK) 
	WHERE EXISTS (SELECT 1 FROM @Msg m WHERE m.MessageId = t.MessageId)

END
GO

