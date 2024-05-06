/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE CustDB
GO

ALTER PROCEDURE [dbo].[Acc_Chatbot_TOControlSetting_Sel]
	@LastLogId BIGINT
	,@BatchSize INT = 10
AS

/*
	Created: 20201214@Malcolm
	DB: DBCUST-CustDB
	Task: Get logIds which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #146735]
        - 20240424@Ned.Le: CRM - Migrate internal accounts to new 2 new sites - Hedging & Special (#202208)

	Param's Explanation:
		

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @NumberOfRows INT, @MaxLogId BIGINT 

	DECLARE @Result TABLE (LogId BIGINT, CustId INT, MatchId INT, NotifiedPercentValue MONEY, IsGroupHeadLine BIT)

	WHILE 1 = 1
	BEGIN
		
		SELECT @MaxLogId = MAX(LogID) FROM TOControl_Setting_History WITH(NOLOCK)

		WAITFOR DELAY '00:00:00.200'

		INSERT INTO @Result (LogId, CustId, MatchId, NotifiedPercentValue, IsGroupHeadLine)
		SELECT TOP(@BatchSize) LogID, h.CustID, Matchid, NotifiedPercentValue, IsGroupHeadLine
		FROM dbo.TOControl_Setting_History h WITH(NOLOCK)
		WHERE h.LogID BETWEEN (@LastLogId + 1) AND @MaxLogId 
		ORDER BY h.LogID	

		IF @@ROWCOUNT = 0
			BREAK

		SELECT @LastLogId = MAX(LogId) FROM @Result

		DELETE @Result WHERE NotifiedPercentValue < 80 OR IsGroupHeadLine = 1

		DELETE r
		FROM @Result r
		WHERE EXISTS(SELECT TOP 1 1 FROM dbo.Customer c WITH(NOLOCK) WHERE c.custid = r.CustId AND c.site IN ('CN88', 'Hedging', 'Special')) 

		SELECT @NumberOfRows = COUNT(1) FROM @Result

		IF @NumberOfRows >= @BatchSize
			BREAK
	END
	
	SELECT TOP(@BatchSize) LogId ,CustId ,MatchId FROM @Result
	ORDER BY LogId

END
GO