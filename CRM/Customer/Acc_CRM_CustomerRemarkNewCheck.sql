/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNewCheck] 
	@Username		NVARCHAR(50) = NULL
	,@IsGuest		BIT = 0
	,@UserRole  TINYINT  
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = ''	OUTPUT
AS
/*
	Created: 20220325@Winfred
	Task : CRM - insert special remarks renovation into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20220325@Winfred: CRM - insert special remarks renovation [RedmineId : #167941]
	
	Parameter's Explanation:
		• @username: the search term.
		• @IsGuest: search by real customer or guest
		@UserRole = 0 : Manager 
		@UserRole = 1 : CN88 staff
		@UserRole = 2 : Company staff
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tmpCustomer TABLE(UserName VARCHAR(50))
	DECLARE @Customer TABLE (
					CustID			INT,
					UserName		VARCHAR(50),
					IsLicensee		BIT, 
					IsSiteActive	BIT
					)	
	
	INSERT INTO @tmpCustomer(UserName)
	SELECT value FROM STRING_SPLIT(@Username,',')  WHERE value <> ''
	
	INSERT INTO @Customer(CustID, UserName, IsLicensee, isSiteActive)
	SELECT c.custid, c.username, 
		CASE WHEN sr.SettingID IS NOT NULL THEN 1 ELSE 0 END as IsLicensee,
		s.isActive
	FROM bodb02.dbo.Customer c WITH (NOLOCK)		
		LEFT JOIN crmSetting s WITH(NOLOCK) ON c.site = s.settingValue AND s.SettingName = 'Site'
		LEFT JOIN crmSettingRelation sr WITH(NOLOCK) ON s.SettingID = sr.SettingID
														AND sr.ParentID = 33000--licensee
	WHERE c.username IN ( SELECT username FROM @tmpCustomer)
		AND ((@UserRole=1 AND c.site = 'CN88') OR (@UserRole=2 AND ISNULL(c.site,'') <> 'CN88'))
	
	INSERT INTO @Customer(CustID, UserName, IsLicensee, IsSiteActive)
	SELECT c.custid, c.username, 
		CASE WHEN sr.SettingID IS NOT NULL THEN 1 ELSE 0 END as IsLicensee,
		s.IsActive 
	FROM crmCustomer c WITH (NOLOCK) 
		INNER JOIN @tmpCustomer tc on c.username = tc.UserName
		LEFT JOIN crmSetting s WITH(NOLOCK) ON c.siteID = s.SettingID 
		LEFT JOIN crmSettingRelation sr WITH(NOLOCK) ON s.SettingID = sr.SettingID
														AND sr.ParentID = 33000--licensee
	WHERE c.CustID < 0	AND @IsGuest = 0
		AND ((@UserRole=1 AND c.SiteID = 33002) OR (@UserRole=2 AND c.SiteID <> 33002))

	INSERT INTO @Customer(CustID, UserName)
	SELECT 0, tc.username 
	FROM @tmpCustomer tc 
	WHERE tc.UserName NOT IN (SELECT UserName FROM @Customer)

	SELECT CustID, UserName as val, ISNULL(IsLicensee,0) IsLicensee, ISNULL(IsSiteActive,0) as IsSiteActive
	FROM @Customer
	ORDER BY UserName 
				
END	