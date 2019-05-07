/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Acc_CRM_LanguageList
(
@UserRole   TINYINT
)
AS
SELECT * FROM crmLanguage WHERE IsActive = 1 AND SiteOffer=@UserRole
GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_LanguageList] TO [bodbAdminNet]
GO 
