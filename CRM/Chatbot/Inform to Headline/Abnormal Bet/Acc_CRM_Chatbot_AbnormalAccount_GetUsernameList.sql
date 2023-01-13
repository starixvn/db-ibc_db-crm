/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalAccount_GetUsernameList]
	@Messages 		XML
	,@SiteDBGroupID SMALLINT
AS

/*
	Created: 20230208@Malcolm
	DB: DBTXN-bodb02
	Task: CRM - ChatBot - Get Username list of tickets belong to abnormal account type
	Revisions:
		- 20210628@Malcolm: Initialize SP [RedmineID: #181906]
		
	Param's Explanation:
		@Messages:
			<root>
				<r VoidingHistoryCollectionId = "1" VoidingHistoryID="1" UsernameList="xxx,u1"/>
				<r VoidingHistoryCollectionId = "1" VoidingHistoryID="2" UsernameList="xxx,u1"/>
				<r VoidingHistoryCollectionId = "1" VoidingHistoryID="15" UsernameList="xxx,u1"/>
			</root>			   
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageLst (VoidingHistoryCollectionId INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, IsValid BIT DEFAULT(0), SiteName NVARCHAR(50))

	INSERT INTO #MessageLst (VoidingHistoryCollectionId, VoidingHistoryId, Username)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@VoidingHistoryID', 'INT') AS VoidingHistoryId
		,u.Username 
	FROM @Messages.nodes('root/r') AS t(c)
	CROSS APPLY
	(
		SELECT f.value AS Username
		FROM STRING_SPLIT(t.c.value('@UsernameList', 'NVARCHAR(MAX)'),',') f
		WHERE f.value <> ''
	) AS u(Username)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	CREATE CLUSTERED INDEX Ix_VoidingHistory ON #MessageLst (VoidingHistoryId)

	UPDATE m
		SET m.CustId = l.custid, m.SiteName = l.site
	FROM #MessageLst m
	CROSS APPLY
	(
		SELECT TOP (1) c.custid, c.site
		FROM CustDB.dbo.Customer c WITH(NOLOCK)
		WHERE c.username = m.Username
	) l
	
	DELETE m
	FROM #MessageLst m
	WHERE EXISTS(
		SELECT 1 FROM CustDB.dbo.Site s WITH(NOLOCK) 
		WHERE s.site = m.SiteName AND s.SiteDBGroupID <> @SiteDBGroupID
	)

	CREATE TABLE #Result (VoidingHistoryId INT, CustId INT)
	CREATE CLUSTERED INDEX Ix_Result ON #Result (VoidingHistoryId)

	INSERT INTO #Result (VoidingHistoryId, CustId)
	SELECT DISTINCT m.VoidingHistoryId, b.CustId
	FROM dbo.zzzbettrans b WITH(NOLOCK)
		INNER JOIN #MessageLst m ON m.VoidingHistoryId = b.VoidingHistoryId AND b.SiteDBGroupID = @SiteDBGroupID

	UPDATE m
		SET m.IsValid = 1
	FROM #MessageLst m
	WHERE EXISTS (
		SELECT 1 FROM #Result r 
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = r.CustId
		WHERE m.VoidingHistoryId = r.VoidingHistoryId	
			AND m.CustId IN (c.custid, c.recommend, c.mrecommend, c.srecommend)
	)

	DELETE #MessageLst WHERE IsValid = 0

	SELECT VoidingHistoryCollectionId, STRING_AGG(r.Username, ',') WITHIN GROUP (ORDER BY r.Username ASC) AS UsernameList
	FROM (
		SELECT DISTINCT VoidingHistoryCollectionId, Username
		FROM #MessageLst
	) AS r
	GROUP BY VoidingHistoryCollectionId

	DROP TABLE #MessageLst
	DROP TABLE #Result
END
GO