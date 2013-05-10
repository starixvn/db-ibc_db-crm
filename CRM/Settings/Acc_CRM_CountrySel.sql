ALTER PROCEDURE [dbo].[Acc_CRM_CountrySel]
AS
/*
Created: Lukas
Date: 20101020
Task : Get country list
DB: DB06.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT 
		CountryID, 
		CountryAbb, 
		CountryName, 
		CountryCode, 
		isActive, 
		DisplayOrder
	FROM 
		crmCountry WITH(NOLOCK)
	ORDER BY 
		CountryName
END


GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CountrySel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CountrySel] TO [vnteam]