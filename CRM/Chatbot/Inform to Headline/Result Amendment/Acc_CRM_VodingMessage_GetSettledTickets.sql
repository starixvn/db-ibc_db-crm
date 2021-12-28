/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_VodingMessage_GetSettledTickets]
	@Message XML
AS
/*
Created: 20211105@Malcolm
Task : Get tickets settled
DB: DBTXN/bodb02
Original:
	Revisions:
		- 20211105@Malcolm: Initialize SPs [Redmine: #164235]
		- 20211206@Malcolm: Exclude Comstatus = 'CO' for CashOut [Redmine: #164235]
	Param's Explanation:
	 @Message:
			<root>
				<r MessageId="1" MsgTargetId="" BetTransId=""/>
			</root>
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Message (MessageId INT, MsgTargetId INT, TransId BIGINT, IsDeleted BIT DEFAULT(1))

	INSERT INTO #Message (MessageId, MsgTargetId, TransId)
	SELECT 
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,n.TransId
	FROM @Message.nodes('root/r') t(c)
	CROSS APPLY (
		SELECT f.val AS TransId
		FROM dbo.f_SplitString(t.c.value('@BetTransId','VARCHAR(MAX)'), ',') AS f
	) AS n
	OPTION (OPTIMIZE FOR (@Message = NULL), MAXRECURSION 0)

	UPDATE m
		SET m.IsDeleted = 0
	FROM #Message m
		INNER JOIN dbo.zzzbettrans b WITH(NOLOCK) ON b.transid = m.TransId 
	WHERE b.status IN ('LOSE', 'DRAW', 'WON') AND ISNULL(b.comstatus, '') <> 'CO'

	;WITH CTE AS
	(
		SELECT m.TransId, MAX(MessageId) AS MaxMessageId
		FROM #Message m
		WHERE m.IsDeleted = 0
		GROUP BY m.TransId
		HAVING COUNT(1) > 1
	)
	UPDATE m	
		SET m.IsDeleted = 1
	FROM #Message m
		INNER JOIN CTE e ON e.TransId = m.TransId AND m.MessageId < e.MaxMessageId

	DELETE #Message WHERE IsDeleted = 1

	CREATE CLUSTERED INDEX ix_Message ON #Message (MessageId, MsgTargetId)

	;WITH CTE AS
	(
		SELECT MessageId, MsgTargetId
		FROM #Message
		GROUP BY MessageId, MsgTargetId
	)
	SELECT 
		e.MessageId
		,e.MsgTargetId
		,STUFF((SELECT ',' + CONVERT(VARCHAR(50), TransId) FROM #Message m WHERE m.MessageId = e.MessageId AND m.MsgTargetId = e.MsgTargetId FOR XML PATH('')), 1, 1, '') AS BetTransId
	FROM CTE e 
	OPTION (MAXRECURSION 0)
		
	DROP TABLE #Message
END
GO

