/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_VodingMessage_GetSettledTickets]
	@Message				XML
	,@SiteDBGroupID			INT
	,@IncludeUUSCurrency	BIT
	,@Environment			VARCHAR(50) = ''
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
		- 20220801@Malcolm: Scale Out [RedmineID: #]
	Param's Explanation:
	 @Message:
			<root>
				<r MessageId="1" MsgTargetId="" BetTransId=""/>
			</root>
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Message (MessageId INT, MsgTargetId INT, TransId BIGINT, IsDeleted BIT DEFAULT(1), IsTest BIT)

	INSERT INTO #Message (MessageId, MsgTargetId, TransId)
	SELECT 
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,n.TransId
	FROM @Message.nodes('root/r') t(c)
	CROSS APPLY (
		SELECT f.value AS TransId
		FROM STRING_SPLIT(t.c.value('@BetTransId','VARCHAR(MAX)'), ',') AS f
	) AS n
	OPTION (OPTIMIZE FOR (@Message = NULL), MAXRECURSION 0)


	IF @IncludeUUSCurrency = 0
	BEGIN
		UPDATE m
			SET m.IsTest = n.IsTest
		FROM #Message m
		CROSS APPLY (
			SELECT TOP(1) CASE WHEN currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE b.transid = m.TransId
		) as n(IsTest)

		UPDATE m
			SET m.IsTest = n.IsTest
		FROM #Message m
		CROSS APPLY (
			SELECT TOP(1) CASE WHEN currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM bodb02.dbo.bettrans14 b WITH(NOLOCK)
			WHERE b.transid = m.TransId 
		) as n(IsTest)
		WHERE m.IsTest IS NULL

		;WITH CTE AS
		(
			SELECT m.MessageId, MIN(CONVERT(TINYINT, m.IsTest)) AS IsTest
			FROM #Message m
			GROUP BY m.MessageId
		)
		DELETE m
		FROM #Message m
			INNER JOIN CTE e ON e.MessageId = m.MessageId
		WHERE @Environment = 'UAT' AND e.IsTest = 0
			OR (@Environment <> 'UAT' AND @IncludeUUSCurrency = 0 AND e.IsTest = 1)
	END

	--If same TransId get the largest messageid
	;WITH CTE AS
	(
		SELECT m.TransId, MAX(MessageId) AS MaxMessageId
		FROM #Message m
		GROUP BY m.TransId
		HAVING COUNT(1) > 1
	)
	DELETE m
	FROM #Message m
		INNER JOIN CTE e ON e.TransId = m.TransId AND m.MessageId < e.MaxMessageId

	UPDATE m
		SET m.IsDeleted = 0
	FROM #Message m
		INNER JOIN dbo.zzzbettrans b WITH(NOLOCK) ON b.transid = m.TransId AND b.SiteDBGroupID = @SiteDBGroupID
	WHERE b.status IN ('LOSE', 'DRAW', 'WON') AND ISNULL(b.comstatus, '') <> 'CO'

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

