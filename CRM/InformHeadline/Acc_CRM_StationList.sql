ALTER PROCEDURE [dbo].[Acc_CRM_StationList]
as
/*
	Created: Elodie
	Date: 20150415
	Task : Get list station from setting
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:	
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	SELECT * FROM crmStation WITH (NOLOCK) WHERE isactive = 1 ORDER BY DisplayOrder
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_StationList] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_StationList] TO [vnteam]