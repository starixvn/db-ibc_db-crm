/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNew_Check] 
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
	
	CREATE TABLE #CustList (
					CustID			INT,
					UserName		VARCHAR(50),
					SiteID			INT,
					IsCredit		INT,					
					IsExists		VARCHAR(50)
					)	
	
	INSERT INTO #CustList(UserName)
	SELECT Data FROM dbo.SplitString(@Username,',')
	
	UPDATE a
	SET a.CustID = b.CustID, IsExists = 1 , a.SiteID = b.SiteID
	FROM #CustList a
		INNER JOIN crmCustomer b WITH(NOLOCK) ON a.UserName = b.UserName
	WHERE @IsGuest = 1 OR (	@IsGuest = 0 AND b.CustID > 0)
	
	UPDATE a
	SET a.IsCredit = CASE WHEN sr.SettingID IS NOT NULL THEN 0 ELSE 1 END
	FROM #CustList a
		LEFT JOIN crmSetting s WITH(NOLOCK) ON a.siteID = s.SettingID 
		LEFT JOIN crmSettingRelation sr WITH(NOLOCK) ON s.SettingID = sr.SettingID
														AND sr.ParentID = 33000--licensee
	WHERE ((@UserRole=1 AND a.SiteID=33002) OR (@UserRole=2 AND ISNULL(a.SiteID,0)<>33002))														
	
	IF EXISTS (SELECT 1 FROM #CustList WITH(NOLOCK) WHERE CustID IS NULL)
	BEGIN
		
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Customer does not exist in IBC system.'
		RETURN										
													
	END
	
	IF EXISTS (SELECT 1 FROM #CustList WITH(NOLOCK) WHERE IsCredit <> 1)
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'Some Usernames not belong to credit Site.'
		RETURN										
													
	END
	DROP TABLE #CustList
				
END	