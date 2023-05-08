/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_CustomerGetUplineList] @CustID INT = NULL
	,@UserName NVARCHAR(50) = NULL
	,@UserRole TINYINT
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
		- 20190905@Winnie: CRM - Left panel did not show Super, Master, Agent  [RedmineId: #119708]
		- 20200320@Tim: fix bug get headline [RedmineId: #129144]
		- 20210705@Johnson: get closed status from CustProductStatus for credit customer [redmine:#152350]
        - 20230508@Ned.Le: [CRM] Headline shown Unassigned if Headline is member level [RedmineID: #187854]
	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @srecommend INT
		,@mrecommend INT
		,@recommend INT

	SELECT @srecommend = srecommend
		,@mrecommend = mrecommend
		,@recommend = recommend
	FROM bodb02.dbo.customer WITH (NOLOCK)
	WHERE CustID = @CustID
		AND (
			(
				@UserRole = 1
				AND [site] = 'CN88'
				)
			OR (
				@UserRole = 2
				AND ISNULL([site], '') <> 'CN88'
				)
			)

	IF @@ROWCOUNT <> 0
	BEGIN
		IF @UserRole = 1
		BEGIN
			SELECT ci.UserName
				,ci.CustID
				,ci.roleid
				,CASE 
					WHEN st.CustStatus = 1 THEN 'Inactive'
					WHEN st.CustStatus = 2 THEN 'Suspended'
					WHEN st.CustStatus = 3 THEN 'View Only'
					WHEN st.CustStatus = 4 THEN 'Active'
					END AS CustStatus
				,ci.Closed AS Locked
			FROM bodb02.dbo.custinfo ci WITH (NOLOCK)
				CROSS APPLY bodb02.dbo.f_CS_GetCustomerStatus(ci.custID) st
			WHERE ci.CustID IN (@srecommend, @mrecommend, @recommend)
			
			UNION ALL
			SELECT ci.UserName
				,ci.CustID
				,7006 AS RoleID
				,CASE 
					WHEN st.CustStatus = 1 THEN 'Inactive'
					WHEN st.CustStatus = 2 THEN 'Suspended'
					WHEN st.CustStatus = 3 THEN 'View Only'
					WHEN st.CustStatus = 4 THEN 'Active'
					END AS CustStatus
				,ci.Closed AS Locked
			FROM bodb02.dbo.custAccount a WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.custAccount h WITH (NOLOCK) ON a.groupID = h.groupID
				AND h.IsGroupHeadLine = 1
				INNER JOIN bodb02.dbo.custInfo ci WITH (NOLOCK) ON h.custid = ci.custid
				CROSS APPLY bodb02.dbo.f_CS_GetCustomerStatus(ci.custID) st
			WHERE a.CustID = @CustID
		END
		ELSE
		BEGIN
			SELECT ci.UserName
				,ci.CustID
				,ci.roleid
				,CASE 
					WHEN (s.custid IS NOT NULL AND ci.Closed = 1)
						OR (s.custid IS NULL AND ISNULL(ps.CloseInfo,0) > 0) THEN 'Closed'
					WHEN (s.custid IS NOT NULL AND ci.Closed = 0 AND ISNULL(ci.reject, 0) = 1)
						OR (s.custid IS NULL AND ISNULL(ps.CloseInfo,0) = 0 AND ISNULL(ps.SuspendInfo,0) >0) THEN 'Suspended'
					WHEN s.custid IS NULL AND ISNULL(ps.Locked,0) > 0 THEN 'Locked'	
					WHEN (s.custid IS NOT NULL AND ci.Closed = 0 AND ISNULL(ci.reject, 0) = 0)
						OR (s.custid IS NULL AND ISNULL(ps.CloseInfo,0) =0 AND ISNULL(ps.SuspendInfo,0)=0) THEN 'Active'
					END AS CustStatus
				,NULL AS Locked
			FROM bodb02.dbo.custinfo ci WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.Dep_CustSuper s WITH(NOLOCK) ON ci.srecommend = s.custid
				LEFT JOIN bodb02.dbo.CustProductStatus ps WITH(NOLOCK) ON ci.custid = ps.custid
			WHERE ci.CustID IN (@srecommend, @mrecommend, @recommend)
			
			UNION ALL
			SELECT h.UserName
				,h.CustID
				,7006 AS RoleID
				,CASE 
					WHEN ISNULL(h.CloseInfo,0) > 0 THEN 'Closed'
					WHEN ISNULL(h.CloseInfo,0) = 0
						AND ISNULL(h.SuspendInfo, 0) > 0 THEN 'Suspended'
					WHEN ISNULL(h.Locked,0) > 0 THEN 'Locked'	
					WHEN ISNULL(h.CloseInfo,0) = 0
						AND ISNULL(h.SuspendInfo, 0) = 0 THEN 'Active'
					END AS CustStatus
				,NULL AS Locked
			FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN bodb02.dbo.custAccount AS upline WITH (NOLOCK) ON c.srecommend = upline.custid
				OR c.mrecommend = upline.custid
				OR c.recommend = upline.custid
                OR c.custid = upline.custid
				CROSS APPLY (
				SELECT ci.custid
					,ci.username
					,ps.CloseInfo
					,ps.SuspendInfo
					,ps.Locked
				FROM bodb02.dbo.custAccount AS h WITH (NOLOCK)
					INNER JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON h.custid = ci.custid
					INNER JOIN bodb02.dbo.CustProductStatus ps WITH(NOLOCK) ON ps.custid = ci.custid
				WHERE upline.groupID = h.groupID
					AND h.IsGroupHeadLine = 1
					AND NOT EXISTS (
						SELECT 1
						FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
						WHERE upline.custid = cd.custid
						)
				) AS h
			WHERE c.CustID = @CustID
				AND ISNULL(upline.groupID, 0) <> 0
		END
	END
END


