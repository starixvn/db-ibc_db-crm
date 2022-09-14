/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_CustomerGetSite]
	@CustID		INT 
AS
/*
	Created:	20220808@Winfred
	Task:		Get site for customer
	DB:			DBCRM/bodb_CRM
	Original:
	Revisions:
		- 20220808@Winfred:	Get site for customer 	[RedmineID:#176234]	
	Param's Explanation:
	Example: EXEC Acc_CRM_CustomerGetSite @CustID = 2
*/


BEGIN
	SET NOCOUNT ON
	DECLARE @Site NVARCHAR(50), @Siteid INT,@SiteidCRM INT, @SiteDBGroupID	SMALLINT
	IF @CustID < 0
	BEGIN
		
		SELECT @SiteidCRM = SiteID FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID
		
		SELECT @Site = m.site
		FROM crmSetting p WITH(NOLOCK)
			INNER JOIN crmSettingRelation r WITH(NOLOCK) on p.SettingID = r.ParentID
			INNER JOIN crmSetting s WITH(NOLOCK) ON r.SettingID = s.SettingID 
			LEFT JOIN crmLicenseeMapping m WITH(NOLOCK) ON s.SettingID = m.SettingID
		WHERE p.SettingName = 'SiteCategory'
			AND p.SettingValue = 'LicenseeSite'
			AND s.isActive = 1
			AND s.SiteOffer = 2
			AND s.SettingID = @SiteidCRM

		SELECT @Siteid =  s.siteid,@Site = s.site,@SiteDBGroupID = s.SiteDBGroupID
		FROM bodb02.dbo.Site AS s WITH (NOLOCK) 
		WHERE s.Site = @Site

	END
	ELSE
	BEGIN
		SELECT @Siteid =  s.siteid,@Site = s.site,@SiteDBGroupID = s.SiteDBGroupID
		FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON c.Site = s.Site
		WHERE c.custid = @CustID
	END

	SELECT @CustID CustID , @Siteid Siteid,@Site Site,@SiteDBGroupID SiteDBGroupID
END
GO