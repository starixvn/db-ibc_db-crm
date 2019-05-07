/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_SiteSel
					@LicenseeType	TINYINT = 0,
					@UserRole		TINYINT
AS
/*
	Created:	20140522@Dom
	Task:		Get all site
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20150403@Elodie:	Filter by licensee type		
		- 20160328@Billy:	Integrate Sub-Product Setting - [Redmine: #50691]
		- 20190507@Winnie:	CN88 	[RedmineID:#112637]	
	Param's Explanation:
		- @LicenseeType =	0: Both
							1: Credit
							2: Licensee

	Example: EXEC Acc_CRM_SiteSel @LicenseeType = 2
*/
BEGIN
	SET NOCOUNT ON
	SELECT	s.SiteID, s.SiteName, s.IsLicensee, s.IsActive
	FROM (
		SELECT	SiteID			=	s.SettingID
			,	SiteName		=	s.SettingValue
			,	IsLicensee		=	CASE sr.ParentID	WHEN 33000 THEN 1
													WHEN 33001 THEN 0
													ELSE -1 
									END			
			,	DisplayOrder	=	s.DisplayOrder
			,	IsActive		=	s.IsActive			
		FROM		crmSettingRelation sr WITH(NOLOCK) 
		INNER JOIN	crmSetting s WITH(NOLOCK)
				ON	sr.SettingID = s.SettingID
				AND	s.SettingName = 'Site'
		WHERE	(ParentID IN (33000, 33001) OR s.SettingID=33002) AND s.SiteOffer=@UserRole
	) s
	WHERE	s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END	
	ORDER BY s.IsActive DESC, s.IsLicensee, s.DisplayOrder
END
GO