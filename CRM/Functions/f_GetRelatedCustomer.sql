


ALTER FUNCTION [dbo].[f_GetRelatedCustomer]
(
	@FeedbackID INT
)
RETURNS @res TABLE ( list VARCHAR(1000))
/*
	Created: 20110629@Lukas
	Task: get Feedback's related customers
	DB: DB06.bodb_CRM
	Original: 

	Revisions:
		-- 20120131@Lukas: get related Guest user
	Param's Explanation:	
*/
AS
BEGIN
	DECLARE @list VARCHAR(1000)

	SELECT @list = COALESCE(@list + ', ' + c.Username, c.Username)
	FROM crmFeedbackCustomer fc WITH(NOLOCK) 
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON fc.CustID = c.CustID
	WHERE FeedbackID = @FeedbackID
		AND IsRelated = 1

	SELECT @list = COALESCE(@list + ', ' + c.Username, c.Username)
	FROM crmFeedbackCustomer fc WITH(NOLOCK) 
		INNER JOIN crmcustomer c WITH(NOLOCK) ON fc.CustID = c.CustID
	WHERE FeedbackID = @FeedbackID
		AND IsRelated = 1
		AND c.custid < 0
	INSERT INTO @res VALUES(ISNULL(@list,''))

	RETURN
END


GO
GRANT VIEW DEFINITION ON f_GetRelatedCustomer to [vnteam]