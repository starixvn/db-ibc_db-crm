/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_ProblemAccount_CustCategorySel] 
	@LastLogID 	INT,
	@BatchSize	INT = 10,
	@ConfigUAT	BIT = 0,
	@ConfigPRO	BIT = 1,	
	@Environment	VARCHAR(10) = 'LIVE'		
AS
/*
	Created: 20210507@Johnson
	Task : get log CustCategoryHistory to create FB for service ProblemAccount
	DB: DBCUST/CustDB
	Original:

	Revisions:
		- 20210507@Johnson: Initial sp [redmine:#153119]
		
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT TOP(@BatchSize)
		c.LogID,
		c.custid,	
		c.CategoryID
	FROM CustCategoryHistory c WITH(NOLOCK)
		INNER JOIN customer ci WITH(NOLOCK) ON c.custid = ci.custid
	WHERE LogID > @LastLogID
		AND CustomerClass BETWEEN 8 AND 12
		AND ci.site = '789y'
		AND ci.roleid = 1		
		AND 1= CASE WHEN ci.currency = 20 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 1
				WHEN ci.currency <> 20 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 1
				ELSE 0 END
	ORDER BY LogID ASC			
END	