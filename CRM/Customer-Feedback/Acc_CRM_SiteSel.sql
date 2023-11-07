/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE	[dbo].[Acc_CRM_SiteSel]
					@LicenseeType	TINYINT = 0,
					@UserRole		TINYINT,
					@Lang			VARCHAR(10)='en-US'
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
		- 20220202@Tacy:	Split 789y site [RedmineID: #182438]
        - 20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

	Param's Explanation:
		- @LicenseeType =	0: Both
							1: Credit
							2: Licensee
		- @Lang	=	en-US
					zh-TW
					zh-CN

	Example: EXEC Acc_CRM_SiteSel_UAT3 @LicenseeType = 1, @UserRole=2
*/

BEGIN
	SET NOCOUNT ON
	IF @UserRole=2
	BEGIN
	SELECT s.SiteLabel, s.SiteID, s.SiteName, s.IsLicensee, s.IsActive
	FROM (
		SELECT	SiteLabel		=	s.ExtraInfo
			,	SiteID			=	s.SettingID
			,	SiteName		=	CASE	WHEN @Lang='zh-TW' THEN ISNULL(s.SettingValueCT,s.SettingValue)
											WHEN @Lang='zh-CN' THEN ISNULL(s.SettingValueCS,s.SettingValue)
											ELSE s.SettingValue
									END
			,	IsLicensee		=	CASE sr.ParentID	WHEN 33000 THEN 1
													WHEN 33001 THEN 0
													ELSE -1 
									END
			,	IsActive		=	s.IsActive			
		FROM		crmSettingRelation sr WITH(NOLOCK) 
		INNER JOIN	crmSetting s WITH(NOLOCK)
				ON	sr.SettingID = s.SettingID
				AND	s.SettingName = 'Site'
		WHERE	ParentID IN (33000, 33001) 
	) s
	WHERE	s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END	
	ORDER BY s.IsActive DESC, s.IsLicensee, s.SiteName
	END
	ELSE IF @UserRole=1
	BEGIN
		SELECT	s.SettingID AS SiteID, CASE	WHEN @Lang='zh-TW' THEN ISNULL(s.SettingValueCT,s.SettingValue)
											WHEN @Lang='zh-CN' THEN ISNULL(s.SettingValueCS,s.SettingValue)
											ELSE s.SettingValue
									END AS SiteName, 
				0 IsLicensee, s.IsActive
		FROM crmSetting s WITH(NOLOCK)
		WHERE s.SettingID=33002
        ORDER BY SiteName
	END
END
GO