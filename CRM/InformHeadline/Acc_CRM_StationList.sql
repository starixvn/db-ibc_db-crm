/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_StationList]
@UserRole TINYINT=2
as
/*
	Created: Elodie
	Date: 20150415
	Task : Get list station from setting
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:	
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637  
        - 20230918@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON
	SELECT StationID,
           Name,
           IsActive,
           SiteOffer,
           NameCS,
           NameCT
    FROM crmStation WITH (NOLOCK) 
	WHERE isactive = 1 AND siteOffer=@UserRole
	ORDER BY Name
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_StationList] TO [bodbAdminNet]
GO 