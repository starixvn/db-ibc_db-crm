/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_CountrySel]
@UserRole INT=2
AS

/*
Created: Lukas
Date: 20101020
Task : Get country list
DB: DB06.bodb_CRM
Original:

Revisions:
		- 20190521@Winnie: SiteOffer CN88
        - 20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

Param's Explanation:	
*/

BEGIN
	SET NOCOUNT ON

	SELECT 
		CountryID, 
		CountryAbb, 
		CountryName, 
		CountryCode, 
		isActive
	FROM 
		crmCountry WITH(NOLOCK)
	WHERE SiteOffer=@UserRole
	ORDER BY 
		CountryName
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CountrySel] TO [bodbAdminNet]