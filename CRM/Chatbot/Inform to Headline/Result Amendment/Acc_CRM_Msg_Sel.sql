/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Msg_Sel]
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

	SELECT t.MessageId, t.MsgTargetId, t.BetTransId
	FROM dbo.Msg m WITH(NOLOCK)
		INNER JOIN dbo.MsgTarget t WITH(NOLOCK) ON t.MessageId = m.MessageId
	WHERE m.MsgContentsType = 102 AND m.PostTime >= GETDATE() - 1

END
GO

