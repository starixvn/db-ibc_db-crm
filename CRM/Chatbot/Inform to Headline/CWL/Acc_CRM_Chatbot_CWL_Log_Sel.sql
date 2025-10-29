/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
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
        - 20230829@Ned.Le: CRM - don't include Company Max Payout rules per ticket (Exclude ActionID=255) into service (#193293)
		- 20250929@Dave: CWL - Headline requests only trigger notifications under specific settings [RedmineId: #239736]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId BIGINT = 0

	SELECT @MaxLogId = MAX(LogID) FROM WinLimit_CustGameMonitoring_History WITH(NOLOCK) WHERE WinlostDate >= CONVERT(DATE, GETDATE() - 1) AND LogID > @LastLogId

	IF ISNULL(@MaxLogId, 0) = 0
	BEGIN
		SELECT TOP(0) '' AS LogID, '' AS CustID, '' AS [CurrencyName], '' AS Username, '' AS Recommend, '' AS Mrecommend, '' AS Srecommend, '' AS Winloss, '' AS ProductID, '' AS LevelID, '' AS GroupID
		RETURN
	END

	WAITFOR DELAY '00:00:00.200'

	;WITH TMP_NormalGroupList AS (
		SELECT GroupID
		FROM dbo.f_GetWinLimit_Group_NormalList('LIVE')
	)
	SELECT TOP(@BatchSize) h.LogID, h.CustID, e.currency AS [CurrencyName], c.Username, c.Recommend, c.Mrecommend, c.Srecommend, h.WinAmt AS Winloss, h.ProductID, h.LevelID, h.GroupID
		, h.TotalWinAmt_RM AS TotalWinAmtRM, p.CasinoType, CASE WHEN ng.GroupID IS NOT NULL THEN 1 ELSE 0 END AS IsNormalGame
	FROM dbo.WinLimit_CustGameMonitoring_History h WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = h.CustID
		INNER JOIN dbo.Site s WITH(NOLOCK) ON s.site = c.site
		INNER JOIN dbo.exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
		INNER JOIN dbo.Products p WITH(NOLOCK) ON p.ProductID = h.ProductID
		LEFT JOIN TMP_NormalGroupList ng ON h.GroupID = ng.GroupID
	WHERE h.LogId > @LastLogId AND h.LogID <= @MaxLogId
		AND h.WinlostDate >= CONVERT(DATE, GETDATE() - 1)
		AND h.ActionID NOT IN (2, 4) AND ActionID < 200
		AND s.isDeposit = 0 AND s.isActive = 1 AND s.site <> 'CN88'
	ORDER BY LogId ASC

END
GO