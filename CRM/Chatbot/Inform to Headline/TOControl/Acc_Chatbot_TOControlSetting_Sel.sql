/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlSetting_Sel]
	@LastLogId BIGINT
	,@BatchSize INT = 10
AS

/*
	Created: 20201214@Malcolm
	DB: DBCUST-CustDB
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Result TABLE (LogId BIGINT, CustId INT, MatchId INT, MaxTurnOver MONEY, NotifiedPercentValue INT)

	INSERT INTO @Result (LogId, CustId, MatchId, MaxTurnOver, NotifiedPercentValue)
	SELECT LogID, CustID, Matchid
	FROM dbo.TOControl_Setting_History h WITH(NOLOCK)
	WHERE h.LogID > @LastLogId  AND NotifiedPercentValue >= 80 
	
	SELECT LogId ,CustId ,MatchId, MaxTurnOver, NotifiedPercentValue FROM @Result

END
GO