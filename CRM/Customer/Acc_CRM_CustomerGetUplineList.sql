/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_CustomerGetUplineList]
(
	@CustID		INT				= NULL,
	@UserName	NVARCHAR(50)	= NULL,
	@UserRole   TINYINT
)
AS
/*
	Created: Lukas
	Date: 20101118
	Task : get customer upline list
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20140303@Dom: Modify for new structure
		- 20180910@Winnie: Show headline [RedmineID: #99982]
		- 201810107@Winnie: Fix bug Show headline [RedmineID: #102925]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20190708@Elodie: Get CN88's customer status [RedmineId: #112637]

	Param's Explanation:	
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @srecommend INT,@mrecommend INT,@recommend INT
	
	SELECT @srecommend = srecommend,@mrecommend=mrecommend,@recommend=recommend
	FROM bodb02.dbo.customer c WITH(NOLOCK) 
	WHERE c.CustID = @CustID
		AND((@UserRole=1 AND c.site = 'CN88') OR(@UserRole=2 AND c.site <> 'CN88'))

	SELECT ci.UserName, ci.CustID, ci.roleid,
		CASE	WHEN @UserRole = 2 THEN CASE	WHEN ci.Closed = 0 AND ISNULL(ci.reject,0) = 0 THEN 'Active'
														WHEN ci.Closed = 0 AND ISNULL(ci.reject,0) = 1 THEN 'Suspended'
														WHEN ci.Closed = 1 THEN 'Closed' END
				WHEN @UserRole = 1 THEN st.CustStatus END AS CustStatus
	FROM bodb02.dbo.custinfo ci WITH(NOLOCK) 
		CROSS APPLY bodb02.dbo.f_CS_GetCustomerStatus(ci.custID) st
	WHERE
		ci.CustID IN (@srecommend,@mrecommend,@recommend)

	UNION ALL
	SELECT	ci.UserName, ci.CustID, 7006 AS RoleID,
			CASE	WHEN @UserRole = 2 THEN CASE	WHEN ci.Closed = 0 AND ISNULL(ci.reject,0) = 0 THEN 'Active'
														WHEN ci.Closed = 0 AND ISNULL(ci.reject,0) = 1 THEN 'Suspended'
														WHEN ci.Closed = 1 THEN 'Closed' END
				WHEN @UserRole = 1 THEN CASE	WHEN st.CustStatus = 1 THEN 'Inactive' 
												WHEN st.CustStatus = 2 THEN 'Suspended' 
												WHEN st.CustStatus = 3 THEN 'View Only' 
												WHEN st.CustStatus = 4 THEN 'Active' END END AS CustStatus
	FROM	bodb02.dbo.custAccount a WITH(NOLOCK) 
			LEFT JOIN bodb02.dbo.custAccount h WITH(NOLOCK) ON a.groupID=h.groupID AND h.IsGroupHeadLine=1
			INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON h.custid=ci.custid
			CROSS APPLY bodb02.dbo.f_CS_GetCustomerStatus(ci.custID) st
	WHERE
		a.CustID IN (@srecommend,@mrecommend,@recommend,@CustID)
END
GO
