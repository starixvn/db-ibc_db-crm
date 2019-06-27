/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Acc_CRM_LanguageList
(
@UserRole		TINYINT,
@Lang			VARCHAR(10)='en-US'
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

SELECT		[LanguageID],
			CASE	WHEN @Lang='zh-TW' THEN ISNULL(NameCT,Name)
					WHEN @Lang='zh-CN' THEN ISNULL(NameCS,Name)
											ELSE Name
			END AS Name,
			DisplayOrder,
			IsActive
 FROM crmLanguage WITH(NOLOCK)
WHERE IsActive = 1 AND ((SiteOffer=@UserRole) )
GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_LanguageList] TO [bodbAdminNet]
GO 
