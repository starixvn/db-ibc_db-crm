CREATE PROCEDURE [dbo].[Acc_CRM_AbnormalAccount_GetUsernameList]
	@Messages 		XML
	,@SiteDBGroupID SMALLINT
AS

/*
	Created: 20210628@Malcolm
	DB: DBTXN-bodb02
	Task: CRM - ChatBot - Get Username list of tickets belong to abnormal account type
	Revisions:
		- 20210628@Malcolm: Initialize SP [RedmineID: #157303]
		- 20220324@Malcolm: replace function f_SplitString with function STRING_SPLIT [RedmineID: #168783]
		- 20220802@Malcolm: Scale out DBTRANS [RedmineID: #175877]
		- 20230131@Winfred: Scale Out for CRM [RedmineId : #181906]
		
	Param's Explanation:
		@Messages:
			<root>
				<r VoidingHistoryCollectionId="1" MessageID="1" RequestID="1" VoidingHistoryID="0" UsernameList="xxx,u1"/>
				<r VoidingHistoryCollectionId="1" MessageID="2" RequestID="2" VoidingHistoryID="0" UsernameList="xxx,u1"/>
				<r VoidingHistoryCollectionId="1" MessageID="3" RequestID="2" VoidingHistoryID="15" UsernameList="xxx,u1"/>
			</root>			   
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageLst (VoidingHistoryCollectionId INT, MessageId INT, RequestID INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, IsValid BIT DEFAULT(0), SiteName NVARCHAR(50))

	INSERT INTO #MessageLst (VoidingHistoryCollectionId, MessageId, RequestID, VoidingHistoryId, Username)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestID
		,t.c.value('@VoidingHistoryID', 'INT') AS VoidingHistoryId
		,u.Username 
	FROM @Messages.nodes('root/r') AS t(c)
	CROSS APPLY
	(
		SELECT f.value AS Username
		FROM STRING_SPLIT(t.c.value('@UsernameList', 'NVARCHAR(MAX)'),',') f
	) AS u(Username)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	CREATE CLUSTERED INDEX Ix_VoidingHistory ON #MessageLst (VoidingHistoryId, MessageId)

	UPDATE m
		SET m.CustId = l.custid, m.SiteName = l.site
	FROM #MessageLst m
	CROSS APPLY
	(
		SELECT TOP 1 c.custid, c.site
		FROM CustDB.dbo.Customer c WITH(NOLOCK)
		WHERE c.username = m.Username
	) l
	
	DELETE m
	FROM #MessageLst m
	WHERE EXISTS(
		SELECT 1 FROM CustDB.dbo.Site s WITH(NOLOCK) 
		WHERE s.site = m.SiteName AND s.SiteDBGroupID <> @SiteDBGroupID
	)

	CREATE TABLE #Result (VoidingHistoryId INT, CustId INT, MessageId INT, RequestId INT, VoidingHistoryCollectionId INT)
	CREATE CLUSTERED INDEX Ix_Result ON #Result (VoidingHistoryId)

	INSERT INTO #Result (VoidingHistoryId, CustId, MessageId, RequestId, VoidingHistoryCollectionId)
	SELECT DISTINCT m.VoidingHistoryId, b.CustId, m.MessageId, m.RequestID, m.VoidingHistoryCollectionId
	FROM dbo.zzzbettrans b WITH(NOLOCK)
		INNER JOIN #MessageLst m ON m.VoidingHistoryId = b.VoidingHistoryId AND b.SiteDBGroupID = @SiteDBGroupID

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
		SELECT DISTINCT MessageId, RequestID , VoidingHistoryCollectionId
		FROM #MessageLst
	)
	SELECT e.MessageId, e.RequestID , e.VoidingHistoryCollectionId
		  ,STUFF((SELECT DISTINCT ',' + m.Username FROM #MessageLst m  WHERE m.Messageid = e.MessageId AND m.RequestID = e.RequestID FOR XML PATH('')), 1, 1, '') AS UsernameList
		  ,STUFF((SELECT DISTINCT ',' + CONVERT(VARCHAR(20), r.CustId) FROM #Result r WHERE r.MessageId = e.MessageId AND r.RequestId = e.RequestID FOR XML PATH('')), 1, 1, '') AS CustIdList
	FROM CTE e

	DROP TABLE #MessageLst
	DROP TABLE #Result
END
GO