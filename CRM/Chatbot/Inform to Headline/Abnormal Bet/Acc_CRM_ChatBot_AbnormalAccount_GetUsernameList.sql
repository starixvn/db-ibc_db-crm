/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_AbnormalAccount_GetUsernameList]
	@Messages XML
AS

/*
	Created: 20210628@Malcolm
	DB: DBTXN-bodb02
	Task: CRM - ChatBot - Get Username list of tickets belong to abnormal account type
	Revisions:
		- 20210628@Malcolm: Initialize SP [RedmineID: #157303]

	Param's Explanation:
		@Messages:
			<root>
				<r MessageID="1" RequestID="1" VoidingHistoryID="0" UsernameList="xxx,u1"/>
				<r MessageID="1" RequestID="2" VoidingHistoryID="0" UsernameList="xxx,u1"/>
				<r MessageID="3" RequestID="2" VoidingHistoryID="15" UsernameList="xxx,u1"/>
			</root>			   
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageLst (MessageId INT, RequestID INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, IsValid BIT DEFAULT(0))

	INSERT INTO #MessageLst (MessageId, RequestID, VoidingHistoryId, Username)
	SELECT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestID
		,t.c.value('@VoidingHistoryID', 'INT') AS VoidingHistoryId
		,u.Username 
	FROM @Messages.nodes('root/r') AS t(c)
	CROSS APPLY
	(
		SELECT f.val AS Username
		FROM f_SplitString(t.c.value('@UsernameList', 'NVARCHAR(MAX)'),',') f
	) AS u(Username)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	CREATE CLUSTERED INDEX Ix_VoidingHistory ON #MessageLst (VoidingHistoryId, MessageId)

	UPDATE m
		SET m.CustId = l.custid
	FROM #MessageLst m
	CROSS APPLY
	(
		SELECT TOP 1 c.custid
		FROM CustDB.dbo.Customer c WITH(NOLOCK)
		WHERE c.username = m.Username
	) l

	CREATE TABLE #Result (VoidingHistoryId INT, CustId INT, MessageId INT, RequestId INT)
	CREATE CLUSTERED INDEX Ix_Result ON #Result (VoidingHistoryId)

	INSERT INTO #Result (VoidingHistoryId, CustId, MessageId, RequestId)
	SELECT DISTINCT m.VoidingHistoryId, b.CustId, m.MessageId, m.RequestID
	FROM dbo.zzzbettrans b WITH(NOLOCK)
		INNER JOIN #MessageLst m ON m.VoidingHistoryId = b.VoidingHistoryId

	UPDATE m
		SET m.IsValid = 1
	FROM #MessageLst m
	WHERE EXISTS (
		SELECT 1 FROM #Result r 
		CROSS APPLY
		(
			SELECT TOP 1 b.custid, b.recommend, b.mrecommend, b.srecommend
			FROM CustDB.dbo.Customer b WITH(NOLOCK)
			WHERE b.CustId = r.CustId
		) AS l
		WHERE m.VoidingHistoryId = r.VoidingHistoryId	
			AND m.CustId IN (l.custid, l.recommend, l.mrecommend, l.srecommend)
	)

	DELETE #MessageLst WHERE IsValid = 0

	;WITH CTE AS
	(
		SELECT DISTINCT MessageId, RequestID
		FROM #MessageLst
	)
	SELECT e.MessageId, e.RequestID
		  ,STUFF((SELECT DISTINCT ',' + m.Username FROM #MessageLst m  WHERE m.Messageid = e.MessageId AND m.RequestID = e.RequestID FOR XML PATH('')), 1, 1, '') AS UsernameList
		  ,STUFF((SELECT DISTINCT ',' + CONVERT(VARCHAR(20), r.CustId) FROM #Result r WHERE r.MessageId = e.MessageId AND r.RequestId = e.RequestID FOR XML PATH('')), 1, 1, '') AS CustIdList
	FROM CTE e

	DROP TABLE #MessageLst
	DROP TABLE #Result
END
GO