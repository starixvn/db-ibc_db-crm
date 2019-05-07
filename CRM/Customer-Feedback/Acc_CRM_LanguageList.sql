/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Acc_CRM_LanguageList
(
@UserRole   TINYINT
)
AS
/*
	Created:	Winnie
	Date:		20190507
	Task :		Get Setting list
	DB:			DBCRM.bodb_CRM
	Original:

	Revisions:
		- 20190507@Winnie:	CN88 	[RedmineID:#112637]
	Param's Explanation:
	
*/
SELECT * FROM crmLanguage WHERE IsActive = 1 AND (SiteOffer=0 OR (SiteOffer=@UserRole) OR @UserRole=0)
GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_LanguageList] TO [bodbAdminNet]
GO 
