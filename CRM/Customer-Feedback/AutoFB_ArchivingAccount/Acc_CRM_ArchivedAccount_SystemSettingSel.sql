/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ArchivedAccount_CheckStatus] 
AS
/*
	Created: Winfred
	Task : CRM -Auto-generated FB to Headline for Archiving Dormant Accounts
	DB: DBACC/bodb02
	Original:

	Revisions:
		- 20221121@Winfred: CRM -Auto-generated FB to Headline for Archiving Dormant Accounts [redmine:#158258]
	
	Parameter's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	DECLARE @status VARCHAR(200)

	SELECT @status = VValue		
	FROM dbo.SystemSettings WITH(NOLOCK) WHERE VName = 'aa_Status'
	
	SELECT CASE @status WHEN 'Stage 1 - Done' THEN 1 ELSE 0 END AS Stage

END	