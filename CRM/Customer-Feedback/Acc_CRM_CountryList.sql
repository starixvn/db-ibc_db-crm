/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Acc_CRM_CountryList
@UserRole INT=2
AS
/*
Created: Winnie
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:	
*/


BEGIN
SELECT [CountryID],[CountryAbb],[CountryName],[CountryCode],[isActive],[DisplayOrder] FROM crmCountry(NOLOCK) 
WHERE IsActive = 1 AND @UserRole=SiteOffer
END
GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_CountryList] TO [bodbAdminNet]
GO 
