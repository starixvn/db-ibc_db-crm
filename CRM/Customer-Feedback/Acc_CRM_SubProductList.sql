/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_SubProductList
					@ProductID	INT = 0,
					@UserRole   TINYINT
AS /*
	Created:	20160323@Billy
	Task:		Get List of SubProduct by ProductID - [Redmine: #52998]
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
	Param's Explanation:
*/
BEGIN
	SELECT	cs.SettingID		SubProductID
		,	cs.SettingValue		Name
		,	csr.ParentID		ProductID
		,	cs.DisplayOrder		DisplayOrder
		,	cs.IsActive			IsActive
	FROM	dbo.crmSetting AS cs WITH (NOLOCK)
	INNER JOIN	dbo.crmSettingRelation AS csr WITH (NOLOCK)
			ON	csr.SettingID = cs.SettingID
	WHERE	cs.SettingName = 'SubProduct'
		AND cs.IsActive = 1
		AND	csr.ParentID = ISNULL(CASE WHEN @ProductID = 0 THEN NULL ELSE @ProductID END, csr.ParentID)
		AND (cs.SiteOffer=0 OR cs.SiteOffer=@UserRole OR @UserRole=0)
	ORDER BY csr.ParentID ASC, cs.DisplayOrder ASC;
END
GO

GRANT EXECUTE ON dbo.Acc_CRM_SubProductList TO bodbAdminNet AS dbo
GO
