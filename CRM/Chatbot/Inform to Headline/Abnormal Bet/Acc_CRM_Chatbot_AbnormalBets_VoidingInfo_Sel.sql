/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_VoidingInfo_Sel]
	@Messages XML
	,@Environment VARCHAR(50) = ''
	,@IncludeUUSCurrency BIT = 1
AS

/*
	Created: 20200811@Percy
	DB: DBACC-bodb02
	Task: CRM - ChatBot - Get Voiding Information

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20210415@Malcolm: Notify Tickets of AB (Real Member) [RedmineId : #153259]
		- 20210415@Malcolm: Integrate Abnormal Accounts [RedmineId : #157303]

	Param's Explanation:
		@Messages:
			<root>
				<r MessageID="1" RequestID="1" UsernameList="xxx,u1" CustIdList=""/>
				<r MessageID="1" RequestID="2" UsernameList="xxx,u1" CustIdList=""/>
				<r MessageID="3" RequestID="2" UsernameList="xxx,u1" CustIdList=""/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @IsTest BIT = NULL

	IF @Environment = 'UAT'
	BEGIN
		SET @IsTest = 1
	END

	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		SET @IsTest = 0
	END

	CREATE TABLE #Messages (MessageId INT, RequestId INT, UsernameList NVARCHAR(MAX), CustIdList VARCHAR(MAX))
	INSERT INTO  #Messages (MessageId, RequestId, UsernameList, CustIdList)
	SELECT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
		,t.c.value('@UsernameList', 'NVARCHAR(MAX)') AS UsernameList
		,t.c.value('@CustIdList', 'VARCHAR(MAX)') AS CustIdList
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	CREATE TABLE #Result (MessageId INT, CustId INT, Username VARCHAR(30), Recommend INT, Mrecommend INT, Srecommend INT, IsTest BIT, [Type] TINYINT)

	-- Get data for abnormal bets, AB
	BEGIN
		CREATE TABLE #AbnormalBetsInfo(MessageId INT, TransId BIGINT)
		INSERT INTO #AbnormalBetsInfo (MessageId, TransId)
		SELECT vh.MessageId, t.TransId
		FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId IN (11, 15) -- Abnormal Bets, AB
			CROSS APPLY (
				SELECT val AS TransId FROM dbo.strSplit(vh.TransIds, ',')
			) t
		WHERE EXISTS (SELECT 1 FROM #Messages m WHERE vh.MessageId = m.MessageId AND vh.RequestId = m.RequestId)
			AND vh.StatusId = 2

		INSERT INTO #Result (MessageId, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest, [Type])
		SELECT vh.MessageId, b.CustId, b.Username, b.Recommend, b.Mrecommend, b.Srecommend, MIN(CONVERT(TINYINT, IsTest)) AS IsTest, 1 AS [Type]
		FROM #AbnormalBetsInfo vh
			CROSS APPLY (
				SELECT TOP 1 b.CustId, b.Username, b.Srecommend, b.Mrecommend, b.Recommend, CASE WHEN b.Currency = 20 THEN 1 ELSE 0 END AS IsTest
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.transid = vh.TransId
			) b
		GROUP BY MessageId,	b.CustId, Username, Srecommend, Mrecommend, Recommend

	END

	-- Get data for abnormal accounts (only get direct account of member who have tickets voided)
	BEGIN
		CREATE TABLE #AbnormalAccountsInfo (MessageId INT, CustId INT, IsTest BIT, DirectAccount INT)
		INSERT INTO #AbnormalAccountsInfo (MessageId, CustId)
		SELECT vh.MessageID, c.CustId
		FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId = 13 -- Abnormal Account
			INNER JOIN #Messages m ON m.MessageId = vh.MessageId AND m.RequestId = vh.RequestId
			CROSS APPLY (SELECT val AS CustId FROM dbo.strSplit(m.CustIdList, ',')) c
		WHERE vh.StatusId = 2

		UPDATE ai
			SET ai.DirectAccount = cda.CustID, ai.IsTest = l.IsTest
		FROM #AbnormalAccountsInfo ai
			CROSS APPLY (
				SELECT TOP 1 C.custid, c.Recommend, c.Mrecommend, c.Srecommend, CASE WHEN c.Currency = 20 THEN 1 ELSE 0 END AS IsTest
				FROM dbo.Customer c WITH(NOLOCK)
				WHERE c.custid = ai.CustId
			) l
			LEFT JOIN dbo.CustDirectAccount cda WITH(NOLOCK) ON cda.CustID IN (l.CustId, l.Recommend, l.Mrecommend, l.Srecommend)

		;WITH CTE AS
		(
			SELECT ai.MessageId, ai.DirectAccount AS CustId, MIN(CONVERT(TINYINT, ai.IsTest)) AS IsTest
			FROM #AbnormalAccountsInfo ai
			GROUP BY ai.MessageId, ai.DirectAccount
		)
		INSERT INTO #Result (MessageId, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest, [Type])
		SELECT e.MessageId, e.CustId, l.Username, l.Recommend, l.Mrecommend, l.Srecommend, e.IsTest, 2 AS [Type]
		FROM CTE e
			OUTER APPLY (
				SELECT TOP 1 c.Username, c.Srecommend, c.Mrecommend, c.Recommend
				FROM dbo.Customer c WITH(NOLOCK)
				WHERE c.custid = e.CustId
			) l
	
	END

	--Get data by environment
	IF @IsTest IS NOT NULL
	BEGIN
		;WITH CTE AS
		(
			SELECT DISTINCT MessageId FROM #Result WHERE IsTest = 0
		)
		DELETE r
		FROM #Result r 
			LEFT JOIN CTE e ON e.MessageId = r.MessageId
		WHERE (e.MessageId IS NULL AND @IsTest = 0) 
			OR (e.MessageId IS NOT NULL AND @IsTest = 1)
	END
	--Return Data
	SELECT
		MessageId
		,ISNULL(CustId, 0) AS CustId 
		,ISNULL(Username, '') AS Username
		,ISNULL(Recommend, 0) AS Recommend
		,ISNULL(Mrecommend, 0) AS Mrecommend
		,ISNULL(Srecommend, 0) AS Srecommend
		,ISNULL(IsTest, 1) AS IsTest
		,[Type]
	FROM #Result
	ORDER BY MessageId ASC

	SELECT 
		m.MessageId
		,m.RequestId
		,m.UsernameList
	FROM #Messages m
	WHERE EXISTS (SELECT 1 FROM #Result r WHERE r.MessageId = m.MessageId)

	DROP TABLE #Messages
	DROP TABLE #Result
	DROP TABLE #AbnormalBetsInfo
	DROP TABLE #AbnormalAccountsInfo	

END
GO