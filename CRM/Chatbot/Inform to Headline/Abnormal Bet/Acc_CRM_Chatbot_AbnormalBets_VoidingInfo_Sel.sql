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
		- 20211125@Malcolm: Notify Tickets of Abnormal Mix Parlay [RedmineId : #163833]
		- 20220115@Malcolm: Scale out for CRM [RedmineId : #181906]

	Param's Explanation:
		@Messages:
			<root>
				<r VoidingHistoryCollectionId = "1" UsernameList=""/>
				<r VoidingHistoryCollectionId = "2" UsernameList="xxx,u1"/>
				<r VoidingHistoryCollectionId = "3" UsernameList="xxx,u1"/>
				<r VoidingHistoryCollectionId = "4" UsernameList="xxx,u1"/>
			</root>
			+ UsernameList: SMA list enter to void tickets
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

	CREATE TABLE #Messages (VoidingHistoryCollectionId INT, UsernameList NVARCHAR(MAX))
	INSERT INTO #Messages (VoidingHistoryCollectionId, UsernameList)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@UsernameList', 'NVARCHAR(MAX)')
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	CREATE TABLE #Result (VoidingHistoryCollectionId INT, CustId INT, UsernameList NVARCHAR(MAX), Recommend INT, Mrecommend INT, Srecommend INT, IsTest BIT, [Type] TINYINT)

	CREATE CLUSTERED INDEX CIX_VoidingHistoryCollectionId ON #Result (VoidingHistoryCollectionId)

	-- Get data for abnormal bets, AB
	BEGIN
		CREATE TABLE #AbnormalBetsInfo(VoidingHistoryCollectionId INT, TransId BIGINT, Username VARCHAR(30), CustId INT, Recommend INT, Mrecommend INT, Srecommend INT, IsTest BIT, [Type] TINYINT)
		INSERT INTO #AbnormalBetsInfo (VoidingHistoryCollectionId, TransId, [Type])
		SELECT vc.VoidingHistoryCollectionId, t.TransId, CASE WHEN rq.IssueTypeId = 11 AND ISNULL(f.FilterBy, 0) = 1 THEN 3 ELSE 1 END AS [Type]
		FROM dbo.VoidingHistoryCollection vc WITH(NOLOCK)
			INNER JOIN dbo.VoidingHistoryCollectionDetail vcd WITH(NOLOCK) ON vcd.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId
			INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON vh.VoidingHistoryId = vcd.VoidingHistoryId
			INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId IN (11, 15) -- Abnormal Bets, AB
			OUTER APPLY (
				SELECT TOP(1) rd.FilterBy 
				FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
				WHERE rd.RequestId = vh.RequestId
			) f(FilterBy)
			CROSS APPLY (
				SELECT value AS TransId 
				FROM STRING_SPLIT(vh.TransIds, ',')
			) t
		WHERE EXISTS (SELECT 1 FROM #Messages m WHERE m.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId)

		UPDATE a
			SET a.CustId = b.CustId, a.Username = b.Username, a.Srecommend = b.Srecommend, a.Mrecommend = b.Mrecommend, a.Recommend = b.Recommend, a.IsTest = b.IsTest
		FROM #AbnormalBetsInfo a
			CROSS APPLY (
				SELECT TOP 1 b.CustId, b.Username, b.Srecommend, b.Mrecommend, b.Recommend, CASE WHEN b.Currency = 20 THEN 1 ELSE 0 END AS IsTest
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.transid = a.TransId
			) b

		UPDATE a
			SET a.CustId = b.CustId, a.Username = b.Username, a.Srecommend = b.Srecommend, a.Mrecommend = b.Mrecommend, a.Recommend = b.Recommend, a.IsTest = b.IsTest
		FROM #AbnormalBetsInfo a
			CROSS APPLY (
				SELECT TOP 1 b.CustId, b.Username, b.Srecommend, b.Mrecommend, b.Recommend, CASE WHEN b.Currency = 20 THEN 1 ELSE 0 END AS IsTest
				FROM dbo.bettrans14 b WITH (NOLOCK)
				WHERE b.transid = a.TransId
			) b
		WHERE a.CustId IS NULL

		INSERT INTO #Result (VoidingHistoryCollectionId, CustId, UsernameList, Recommend, Mrecommend, Srecommend, IsTest, [Type])
		SELECT a.VoidingHistoryCollectionId, a.CustId, a.Username, a.Recommend, a.Mrecommend, a.Srecommend, MIN(CONVERT(TINYINT, a.IsTest)) AS IsTest, MAX(a.[Type]) AS [Type]
		FROM #AbnormalBetsInfo a
		GROUP BY a.VoidingHistoryCollectionId, a.CustId, a.Username, a.Srecommend, a.Mrecommend, a.Recommend

	END

	-- Get data for abnormal accounts (only get direct account of member who have tickets voided)
	BEGIN
		CREATE TABLE #AbnormalAccountsInfo (VoidingHistoryCollectionId INT, Username VARCHAR(30), CustId INT, Recommend INT, Mrecommend INT, Srecommned INT, IsTest BIT, DirectAccount INT)
		INSERT INTO #AbnormalAccountsInfo (VoidingHistoryCollectionId, Username, CustId, Recommend, Mrecommend, Srecommned, DirectAccount, IsTest)
		SELECT m.VoidingHistoryCollectionId, f.Username, c.custid, c.recommend, c.mrecommend, c.srecommend, cda.CustID, CASE WHEN c.Currency = 20 THEN 1 ELSE 0 END AS IsTest
		FROM #Messages m
			CROSS APPLY (
				SELECT CONVERT(VARCHAR(30), f.value) AS Username
				FROM STRING_SPLIT(m.UsernameList, ',') f
				WHERE f.value <> ''
			) AS f(Username)
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.username = f.Username
			LEFT JOIN dbo.CustDirectAccount cda WITH(NOLOCK) ON cda.CustID IN (c.custid, c.recommend, c.mrecommend, c.srecommend)
		WHERE m.UsernameList <> ''

		CREATE INDEX ix_MessageId ON #AbnormalAccountsInfo (VoidingHistoryCollectionId, DirectAccount)

		;WITH CTE AS
		(
			SELECT ai.VoidingHistoryCollectionId, ai.DirectAccount, MIN(CONVERT(TINYINT, ai.IsTest)) AS IsTest, STRING_AGG(ai.Username, ',') AS UsernameList
			FROM #AbnormalAccountsInfo ai
			GROUP BY ai.VoidingHistoryCollectionId, ai.DirectAccount
		)
		INSERT INTO #Result (VoidingHistoryCollectionId, CustId, UsernameList, Recommend, Mrecommend, Srecommend, IsTest, [Type])
		SELECT e.VoidingHistoryCollectionId, e.DirectAccount, e.UsernameList, c.Recommend, c.Mrecommend, c.Srecommend, e.IsTest, 2 AS [Type]
		FROM CTE e
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = e.DirectAccount
	END

	--Get data by environment
	IF @IsTest IS NOT NULL
	BEGIN
		;WITH CTE AS
		(
			SELECT DISTINCT VoidingHistoryCollectionId FROM #Result WHERE IsTest = 0
		)
		DELETE r
		FROM #Result r 
			LEFT JOIN CTE e ON e.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId
		WHERE (e.VoidingHistoryCollectionId IS NULL AND @IsTest = 0) 
			OR (e.VoidingHistoryCollectionId IS NOT NULL AND @IsTest = 1)
	END
	--Return Data
	SELECT
		VoidingHistoryCollectionId
		,ISNULL(CustId, 0) AS CustId 
		,ISNULL(UsernameList, '') AS UsernameList
		,ISNULL(Recommend, 0) AS Recommend
		,ISNULL(Mrecommend, 0) AS Mrecommend
		,ISNULL(Srecommend, 0) AS Srecommend
		,ISNULL(IsTest, 1) AS IsTest
		,[Type]
	FROM #Result
	ORDER BY VoidingHistoryCollectionId ASC
	
	SELECT vcd.VoidingHistoryCollectionId, vh.MessageId, vh.RequestId
	FROM dbo.VoidingHistoryCollectionDetail vcd WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = vcd.VoidingHistoryId
	WHERE EXISTS (SELECT 1 FROM #Result m WHERE m.VoidingHistoryCollectionId = vcd.VoidingHistoryCollectionId)
	ORDER BY vcd.VoidingHistoryCollectionId ASC
	
	DROP TABLE #Result
	DROP TABLE #Messages
	DROP TABLE #AbnormalBetsInfo
	DROP TABLE #AbnormalAccountsInfo	
END
GO