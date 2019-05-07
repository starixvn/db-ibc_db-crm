/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Acc_CRM_MainCategoryList
(
@UserRole		TINYINT
)
AS
BEGIN
SELECT * FROM crmMainCategory(nolock) where IsActive = 1
	AND siteOffer=@UserRole
END
GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_MainCategoryList] TO [bodbAdminNet]
GO 
