/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ProblemAccounts_Sel]
	@LastLogId  BIGINT
	,@BatchSize INT = 1000
AS

/*
	Created: 20210426@Malcolm
	DB: DBCUST-CustDB
	Task: CRM - Problem Account - Get Problem Accounts (Only member Level)

	Revisions:
		- 20210426@Malcolm: Initialize SP [RedmineId: #153119]
		- 20220330@Malcolm: Get CustomerClass from CategoryConfig table [RedmineId: #170666]
		- 20221020@Malcolm: Hide problem accounts (group betting) [redmine: #179370]
		- 20230207@Malcolm: Split 789y site [redmine: #182438]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId BIGINT

	SELECT @MaxLogId = MAX(LogID) FROM dbo.CustCategoryHistory WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	SELECT TOP(@BatchSize)  h.LogId, c.username, h.CustId, c.recommend, c.mrecommend, c.srecommend, h.CategoryId, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
	FROM dbo.CustCategoryHistory h WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = h.custid 
		INNER JOIN dbo.Site s WITH(NOLOCK) ON s.site = c.site
	WHERE c.roleid = 1 AND s.SiteLabel = '789y' AND h.LogID > @LastLogId AND h.LogID <= @MaxLogId	
		AND EXISTS (SELECT 1 FROM dbo.CategoryConfig cg WITH(NOLOCK) WHERE cg.CustomerClass = h.CustomerClass AND HiddenSite IN (0, 2))
	ORDER BY h.LogID ASC
END

