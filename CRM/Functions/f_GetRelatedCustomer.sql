/*<info serverAlias="DBCRM-bodb_CRM" selecters="bodbAdminNet" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_GetRelatedCustomer]
(
	@FeedbackID INT
)
RETURNS TABLE
/*
	Created: 20110629@Lukas
	Task: get Feedback's related customers
	DB: DBCRM/bodb_CRM
	Original: 

	Revisions:
		-- 20120131@Lukas: get related Guest user
		- 20190614@Helen: CN88 - Performance Tuning [Redmine: #112637]
		
	Param's Explanation:	
*/
AS
RETURN 
	SELECT ISNULL(STUFF((SELECT ',' + t.username
	FROM
		(
			SELECT c.Username
			FROM crmFeedbackCustomer fc WITH(NOLOCK) 
				INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON fc.CustID = c.CustID
			WHERE FeedbackID = @FeedbackID
				AND IsRelated = 1
				
			UNION ALL
			
			SELECT c.Username
			FROM crmFeedbackCustomer fc WITH(NOLOCK) 
				INNER JOIN crmcustomer c WITH(NOLOCK) ON fc.CustID = c.CustID
			WHERE FeedbackID = @FeedbackID
				AND IsRelated = 1
				AND c.custid < 0
		
		) AS t
	FOR XML PATH ('')), 1,1, ''), '') AS list

GO	
	
