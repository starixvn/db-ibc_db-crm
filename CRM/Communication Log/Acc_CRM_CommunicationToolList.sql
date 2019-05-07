/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Acc_CRM_CommunicationToolList
(
@UserRole		TINYINT
)
AS
/*
	Created:	Winnie
	Date:		20141118
	Task:		get list Licensee Type
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20190507@Winnie:	CN88 	[RedmineID:#112637]
	Param's Explanation:
*/
SELECT * FROM crmCommunicationTool(NOLOCK) WHERE IsActive = 1 AND (siteOffer=@UserRole OR SiteOffer=0 OR @UserRole=0)				
GO
 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CommunicationToolList] TO [bodbAdminNet]
GO 
