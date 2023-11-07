/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE Acc_CRM_LanguageList
(
	@UserRole		TINYINT,
	@Active			TINYINT = 1,
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
		- 20201030@Johnson: add filter IsActive [redmine: #142194]
        - 20230918@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

	Param's Explanation:
		- @Active = 1: get active
				= 2: get all 
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT		[LanguageID],
				CASE	WHEN @Lang='zh-TW' THEN ISNULL(NameCT,Name)
						WHEN @Lang='zh-CN' THEN ISNULL(NameCS,Name)
												ELSE Name
				END AS Name,
				IsActive
	FROM crmLanguage WITH(NOLOCK)
	WHERE 1 = CASE WHEN (@Active = 1 AND IsActive = 1) OR @Active = 2 THEN 1 ELSE 0 END
		AND ((SiteOffer=@UserRole) )
    ORDER BY Name
END		
GO
