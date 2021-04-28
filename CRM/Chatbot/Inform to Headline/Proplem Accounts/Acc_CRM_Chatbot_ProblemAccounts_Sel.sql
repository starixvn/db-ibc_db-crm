/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ProblemAccounts_Sel]
		@LastLogId  INT
		,@BatchSize INT = 300
AS

/*
	Created: 20210426@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - Problem Account - Get Problem Accounts (Only member Level)

	Revisions:
		- 20210426@Malcolm: Initialize SP [RedmineId: #153119]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId BIGINT, @RowNumber INT

	SELECT @MaxLogId = MAX(LogID) FROM dbo.CustCategoryHistory WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	DECLARE @Tmp TABLE (LogId BIGINT, CustId INT, CategoryId SMALLINT, CustomerClass TINYINT)

	WHILE 1 = 1
	BEGIN
		INSERT INTO @Tmp (LogId, CustId, CategoryId, CustomerClass)
		SELECT h.custid, h.CategoryID, h.CustomerClass
		FROM dbo.CustCategoryHistory h WITH(NOLOCK)
		WHERE h.LogID > @LastLogId AND h.LogID <= @MaxLogId
		ORDER BY h.LogID ASC

		IF @@ROWCOUNT = 0
			BREAK

		DELETE @Tmp WHERE CustomerClass NOT BETWEEN 8 AND 11

		DELETE t
		FROM @Tmp t
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = t.CustId
		WHERE c.roleid <> 1 OR c.site <> '789y'

		SELECT @RowNumber = COUNT(1) FROM @Tmp

		IF @RowNumber >= @BatchSize
		BEGIN	
			BREAK
		END
	END

	SELECT TOP (@BatchSize) t.LogId, c.username, t.CustId,c.recommend, c.mrecommend, c.srecommend, t.CategoryId, CASE WHEN c.currency = 'UUS' THEN 1 ELSE 0 END AS IsTest
	FROM @Tmp t
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = t.CustId
	ORDER BY LogId ASC
	
END
