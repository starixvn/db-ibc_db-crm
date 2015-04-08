ALTER PROCEDURE [dbo].[Acc_CRM_CurrencySel]	
AS

/*
	Created: 20150403@Elodie
	Task :  Get all currency
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
			
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	SELECT exchangeid, currency
	FROM bodb02.dbo.Exchange WITH (NOLOCK)
	ORDER BY currency
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_CurrencySel] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CurrencySel] TO [vnteam]