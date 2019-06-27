/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_BettypeList]
	@ProductID		INT = null,
	@UserRole		TINYINT,
	@Lang			VARCHAR(10)='en-US'
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

SELECT [BettypeID],
		CASE	WHEN @Lang='zh-TW' THEN ISNULL(NameCT,Name)
					WHEN @Lang='zh-CN' THEN ISNULL(NameCS,Name)
											ELSE Name
			END AS Name,
		[ProductID],[DisplayOrder],IsActive 
FROM crmBettype WITH(NOLOCK) 
WHERE IsActive = 1 and (ISNULL(@ProductID,0)=0 OR ProductID = @ProductID)
	AND (SiteOffer=@UserRole)

GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_BettypeList] TO [bodbAdminNet]
GO 
