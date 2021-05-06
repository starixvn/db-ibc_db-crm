/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_VoidingInfo_Sel]
	@Messages XML
AS

/*
	Created: 20200811@Percy
	DB: DBACC-bodb02
	Task: CRM - ChatBot - Get Voiding Information

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20210415@Malcolm: Notify Tickets of AB (Real Member) [RedmineId : #153259]

	Param's Explanation:
		@Messages:
			<root>
				<r MessageID=1 RequestID=1 />
				<r MessageID=1 RequestID=2 />
				<r MessageID=3 RequestID=2 />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (MessageId INT, RequestId INT)
	INSERT INTO  #Messages (MessageId, RequestId)
	SELECT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	CREATE TABLE #VoidingHistory (MessageId INT, TransId BIGINT)
	INSERT INTO #VoidingHistory (MessageId, TransId)
	SELECT vh.MessageId, t.TransId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId IN (11, 15) -- Abnormal Bets, AB
		CROSS APPLY (
			SELECT val AS TransId FROM dbo.strSplit(vh.TransIds, ',')
		) t
	WHERE EXISTS (SELECT 1 FROM #Messages m WHERE vh.MessageId = m.MessageId AND vh.RequestId = m.RequestId)
		AND vh.StatusId = 2

	-- Return Data
	BEGIN
		SELECT vh.MessageId, b.CustId, b.Username, b.Srecommend, b.Mrecommend, b.Recommend, MAX(IsTest) AS IsTest
		FROM #VoidingHistory vh
			CROSS APPLY (
				SELECT TOP 1 b.CustId, b.Username, b.Srecommend, b.Mrecommend, b.Recommend, CASE WHEN b.Currency = 20 THEN 1 ELSE 0 END AS IsTest
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.transid = vh.TransId
			) b
		GROUP BY vh.MessageId, b.CustId, b.Username, b.Srecommend, b.Mrecommend, b.Recommend
	END

	DROP TABLE #Messages
	DROP TABLE #VoidingHistory
END
GO