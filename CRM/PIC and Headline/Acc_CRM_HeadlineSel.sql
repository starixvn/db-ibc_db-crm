/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_HeadlineSel]
	@Username VARCHAR(30) = ''
AS
/*
Created: 20200511@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200511@Malcolm: Get all headline of system [Redmine: #108739]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON

	SELECT @Username = ISNULL(@Username,'')

	SELECT c.custid AS HeadlineID,
		   t.username AS HeadlineName
	FROM bodb02.dbo.CustGroupHeadline c WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer t WITH(NOLOCK) ON c.custid = t.custid
		LEFT  JOIN bodb02.dbo.Customer ag WITH(NOLOCK) ON ag.custid = t.recommend AND t.roleid = 1
	WHERE (@Username = '' OR t.username LIKE '%'+ @Username + '%') AND c.GroupID <> 0 AND ISNULL(ag.site, t.site) <> 'CN88'

	UNION ALL
	-- for direct account which haven't headline group
	SELECT 0 AS HeadlineID,'Not assigned group' AS HeadlineName
END
GO