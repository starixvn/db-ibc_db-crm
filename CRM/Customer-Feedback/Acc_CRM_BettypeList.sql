/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_BettypeList]
	@ProductID	INT = null,
	@UserRole   TINYINT
as

/*
	Created: Dom
	Date: 20140217
	Task : Get List of sub categories
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
	Param's Explanation:
	
*/

select [BettypeID],[Name],[ProductID],[DisplayOrder],IsActive from crmBettype(nolock) 
WHERE IsActive = 1 and (ISNULL(@ProductID,0)=0 OR ProductID = @ProductID)
	AND (SiteOffer=0 OR SiteOffer=@UserRole OR @UserRole=0)

GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_BettypeList] TO [bodbAdminNet]
GO 
