/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_CWL_Log_Sel]
	@LastLogId	INT
	,@BatchSize INT = 10
AS

/*
	Created: 20201104@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - CWL - Get Customer Win Loss Limit Reach Log Information

	Revisions:
		- 20201104@Malcolm: Initialize SP [RedmineId: #144265]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RowCount INT

	DECLARE @Result TABLE
	(
		LogId				BIGINT
		,CustId				INT
		,CurrencyName		NVARCHAR(50)
		,Username			VARCHAR(30)
		,Recommend			INT
		,Mrecommend			INT
		,Srecommend			INT
		,Winloss			MONEY
		,ProductId			TINYINT
		,LevelId			INT
		,GroupId			INT
		,WinlostDate		SMALLDATETIME
	)

	DECLARE @tmpLogId BIGINT = @LastLogId

	WHILE 1 = 1
	BEGIN
		INSERT INTO @Result
		(
			LogId, CustId, ProductId, GroupId, WinlostDate
		)
		SELECT TOP (@BatchSize) LogId, CustId, ProductId, GroupId, WinlostDate
		FROM dbo.WinLimit_CustGameMonitoring_History WITH (NOLOCK)
		WHERE LogId > @tmpLogId

		IF @@ROWCOUNT = 0
			BREAK

		UPDATE r
		SET r.LevelId = h.LevelId, r.Winloss = h.WinAmt
		FROM @Result r
			INNER JOIN dbo.WinLimit_CustGameMonitoring_History h WITH (NOLOCK)
				ON	r.CustId = h.CustId
					AND r.ProductId = h.ProductId
					AND r.GroupID = h.GroupID
					AND r.WinlostDate = h.WinlostDate

		UPDATE r
		SET r.Username =  c.username
			,r.recommend = c.recommend
			,r.mrecommend = c.mrecommend
			,r.srecommend = c.srecommend
			,r.CurrencyName = e.currency	
		FROM @Result r
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.CustId = r.CustId
			INNER JOIN dbo.exchange e WITH (NOLOCK) ON e.ExchangeId = c.Currency
			INNER JOIN dbo.Customer a WITH (NOLOCK) ON c.recommend = a.CustId
			INNER JOIN dbo.Site s WITH (NOLOCK) ON s.site = a.site
		WHERE s.isDeposit = 0 AND s.isActive = 1 AND s.site <> 'CN88'

		SELECT @RowCount = @RowCount + @@ROWCOUNT

		IF @RowCount = @BatchSize
			BREAK
		ELSE IF @RowCount > @BatchSize
		BEGIN
			DELETE @Result WHERE recommend IS NULL

			DELETE t
			FROM (
				SELECT LogId, ROW_NUMBER() OVER(ORDER BY LogId) AS RN
				FROM @Result
			) t
			WHERE RN > @BatchSize

			BREAK
		END

		DELETE @Result WHERE recommend IS NULL
		SELECT @tmpLogId = MAX(LogId) FROM @Result
	END

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