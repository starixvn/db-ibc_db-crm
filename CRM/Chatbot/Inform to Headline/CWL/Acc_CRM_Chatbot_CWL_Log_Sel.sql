/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_CWL_Log_Sel]
	@LastLogId	BIGINT
	,@BatchSize INT = 10
AS

/*
	Created: 20201104@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - CWL - Get Customer Win Loss Limit Reach Log Information

	Revisions:
		- 20201104@Malcolm: Initialize SP [RedmineId: #144265]
		- 20210626@Percy: Fix code loop LogId [RedmineId: #144265]
		- 20210627@Malcolm: remove WHILE loop [RedmineId: #144265]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId INT = 0

	DECLARE @Result TABLE
	(
		LogId			BIGINT
		,CustId			INT
		,Currency		INT
		,CurrencyName	NVARCHAR(50)
		,Username		VARCHAR(30)
		,Recommend		INT
		,Mrecommend		INT
		,Srecommend		INT
		,Winloss		MONEY
		,ProductId		TINYINT
		,LevelId		INT
		,GroupId		INT
		,ActionID		TINYINT
	)

	SELECT @MaxLogId = MAX(LogID) FROM WinLimit_CustGameMonitoring_History WITH(NOLOCK) WHERE WinlostDate >= CONVERT(DATE, GETDATE() - 1)

	WAITFOR DELAY '00:00:00.200'

	INSERT INTO @Result (LogId, CustId, Username, Recommend, Mrecommend, Srecommend, Winloss, ProductId, LevelId, GroupId, ActionID, Currency)
	SELECT TOP(@BatchSize) h.LogID, h.CustID, c.username, c.recommend, c.mrecommend, c.srecommend, h.WinAmt, h.ProductID, h.LevelID, h.GroupID, h.ActionID, c.currency
	FROM dbo.WinLimit_CustGameMonitoring_History h WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = h.CustID
		INNER JOIN dbo.Site s WITH(NOLOCK) ON s.site = c.site
	WHERE LogId BETWEEN (@LastLogId + 1) AND @MaxLogId
		AND WinlostDate >= CONVERT(DATE, GETDATE() - 1)
		AND ActionID NOT IN (2, 4)
		AND s.isDeposit = 0 AND s.isActive = 1 AND s.site <> 'CN88'
	ORDER BY LogId ASC

	UPDATE r
		SET r.CurrencyName = e.currency
	FROM @Result r
		INNER JOIN dbo.exchange e WITH(NOLOCK) ON e.ExchangeId = r.Currency

	SELECT
		LogId
		,CustId
		,CurrencyName
		,Username
		,Recommend
		,Mrecommend
		,Srecommend
		,Winloss
		,ProductId
		,LevelId
		,GroupId
	FROM @Result
	ORDER BY LogId
END
GO