/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlGet_Sel]
	@LastDatetime DATETIME
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		.@XML = <root><r CustId ="" Username ="" RoleId ="" CurrencyName ="" MatchId =""> </r><root/>

*/
BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT CustID, matchid
	FROM dbo.TOControl_Setting t WITH(NOLOCK)
	WHERE t.NotifiedPercentValue > 60 AND t.ModifiedDatePercentValue > @LastDatetime AND IsGroupHeadLine = 0

END