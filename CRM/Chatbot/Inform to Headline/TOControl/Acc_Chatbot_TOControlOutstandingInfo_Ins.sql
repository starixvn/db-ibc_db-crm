/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlOutstandingInfo_Ins]
	@XML   XML
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		.@XML = '<root><r LogId="" CustId ="" MatchId =""> </r><root/>'

*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@XML, '') = ''
	BEGIN
		RETURN
	END

	DECLARE @Result TABLE
	(
		LogId					BIGINT,
		CustId					INT, 	
		UserName				VARCHAR(30),
		RoleId					TINYINT,
		MatchId					INT, 
		CurrencyName			NVARCHAR(50),
		Outstanding				MONEY
	)	

	INSERT INTO @Result (LogId, CustId, UserName, RoleId, MatchId, CurrencyName)
	SELECT 
		T.c.value('@LogId', 'BIGINT')					AS LogId
		,T.c.value('@CustId', 'INT')					AS CustId
		,T.c.value('@MatchId', 'INT')					AS MatchId
	FROM @XML.nodes('root\r') T(c)
	OPTION (OPTIMIZER FOR (@XML = NULL))
	
	DECLARE @LastLogId BIGINT

	SELECT @LastLogId = MAX(LogId) FROM @Result

	-- Get Outstanding
	IF EXISTS(SELECT 1 FROM @Result WHERE RoleId = 4)
	BEGIN
		;WITH CTE AS (
			SELECT b.srecommend,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE b.srecommend IN (SELECT r.CustId FROM @Result r)
				AND b.statusID IN (0, 1)
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM @Result r
			INNER JOIN CTE e ON e.srecommend = r.CustId	 
	END

	IF EXISTS(SELECT 1 FROM @Result WHERE RoleId = 3)
	BEGIN
		;WITH CTE AS (
			SELECT b.mrecommend,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE b.mrecommend IN (SELECT r.CustId FROM @Result r)
				AND b.statusID IN (0, 1)
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM @Result r
			INNER JOIN CTE e ON e.mrecommend = r.CustId	 
	END

	IF EXISTS(SELECT 1 FROM @Result WHERE RoleId = 2)
	BEGIN
		;WITH CTE AS (
			SELECT b.recommend,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE b.recommend IN (SELECT r.CustId FROM @Result r) 
				AND b.statusID IN (0, 1)
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM @Result r
			INNER JOIN CTE e ON e.recommend = r.CustId	 
	END
	
	INSERT INTO dbo.crmTOControlOutstandingInfo (LogId, CustId, MatchId, Outstanding)
	SELECT t.LogId, t.CustId, t.MatchId, t.Outstanding
	FROM @Result t
	WHERE NOT EXISTS(SELECT TOP 1 1 FROM dbo.crmTOControlOutstandingInfo i WITH(NOLOCK) WHERE i.LogID = t.LogId)

	UPDATE s
		SET s.Value = CONVERT(VARCHAR(50), @LastLogId)
	FROM SystemSetting s
	WHERE s.ServiceName = 'ChatBot - TOControl' AND s.SettingName = 'HistoricLastLog'
	
END
GO