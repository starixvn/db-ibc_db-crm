/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControl_SMAInfo_Sel]
	@LastLogId BIGINT
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

	DECLARE @Result TABLE (LogId BIGINT, CustId INT, MatchId INT, RoleId TINYINT, UserName VARCHAR(30), CurrencyName NVARCHAR(50), Outstanding MONEY)

	INSERT INTO @Result (LogId, CustId, MatchId)
	SELECT LogID, CustID, Matchid
	FROM dbo.TOControl_Setting_History h WITH(NOLOCK)
	WHERE h.LogID > @LastLogId  AND NotifiedPercentValue >= 80 

	UPDATE r
		SET r.CurrencyName	= l.Currency
			,r.UserName		= l.Username
			,r.RoleId		= l.RoleId
	FROM @Result r
	CROSS APPLY(
		SELECT TOP (1) Username , e.Currency , RoleId 
		FROM dbo.Customer c WITH(NOLOCK)
			INNER JOIN dbo.exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
		WHERE c.custid = r.CustId
	) AS l
	
	SELECT LogId ,CustId ,MatchId ,RoleId ,UserName ,CurrencyName FROM @Result

END
GO