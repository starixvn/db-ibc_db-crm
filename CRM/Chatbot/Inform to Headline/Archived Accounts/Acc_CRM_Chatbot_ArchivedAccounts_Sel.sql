/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ArchivedAccounts_Sel]
	@LastLogId  BIGINT
	,@BatchSize INT = 1000
AS

/*
	Created: 20210426@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - Archived Account - Get Archived Accounts (Only direct account)

	Revisions:
		- 20210426@Malcolm: Initialize SP [RedmineId: #158258]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId BIGINT

	SELECT @MaxLogId = MAX(LogID) FROM dbo.crmArchivedAccount WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	SELECT TOP(@BatchSize) h.LogId, c.username, h.CustId, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
	FROM dbo.crmArchivedAccount h WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = h.custid 
	WHERE h.LogID <= @MaxLogId AND h.LogID > @LastLogId
	ORDER BY h.LogID ASC
END
