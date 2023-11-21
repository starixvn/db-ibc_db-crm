/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_VodingMessage_GetSettledTickets]
	@Message		XML
	,@SiteDBGroupId INT
AS
/*
	Created: 20211105@Malcolm
	Task : Get tickets settled
	DB: DBTXN/bodb02
	Original:
	Revisions:
		- 20211105@Malcolm: Initialize SPs [Redmine: #164235]
		- 20211206@Malcolm: Exclude Comstatus = 'CO' for CashOut [Redmine: #164235]
		- 20220324@Malcolm: replace function f_SplitString with function STRING_SPLIT [RedmineID: #168783]
		- 20231017@Malcolm: Add MsgContentsType, MatchId [Redmine: #195404]
	Param's Explanation:
	 @Message:
			<root>
				<r MessageId="1" MsgTargetId="" BetTransId="" MsgContentsType="" MatchId="" />
			</root>
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Message (MessageId INT, MsgTargetId INT, TransId BIGINT, MsgContentsType TINYINT, MatchId INT, IsDeleted BIT DEFAULT(1))

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
	OPTION (OPTIMIZE FOR (@Message = NULL), MAXRECURSION 0)

	UPDATE m
		SET m.IsDeleted = 0
	FROM #Message m
		INNER JOIN dbo.zzzbettrans b WITH(NOLOCK) ON b.transid = m.TransId 
	WHERE b.status IN ('LOSE', 'DRAW', 'WON') AND ISNULL(b.comstatus, '') <> 'CO' AND b.SiteDBGroupID = @SiteDBGroupId

	DELETE #Message WHERE IsDeleted = 1

	CREATE CLUSTERED INDEX ix_Message ON #Message (MessageId, MsgTargetId)

	SELECT MessageId, MsgTargetId, MsgContentsType, MatchId, STRING_AGG(CONVERT(VARCHAR(MAX), TransId), ',') AS BetTransId
	FROM #Message
	GROUP BY MessageId, MsgTargetId, MsgContentsType, MatchId
		
	DROP TABLE #Message
END
GO

