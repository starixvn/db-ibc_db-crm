/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_SettingSel
(
	@UserRole			TINYINT = NULL,
	@Lang				VARCHAR(10)='en-US',
	@SettingName		VARCHAR(50) = '',
	@IsActive			BIT = NULL,
	@IncludedSettingID	VARCHAR(200) = ''
)
AS
/*
	Created:	Khoa
	Date:		20101020
	Task :		Get Setting list
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20120425@Sophia:	Edit Order by DisplayOrder before SettingID 
		- 20160301@Billy:	Support Active/Inactive function - [Redmine: #53173]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20200421@Johnson: get mapping setting for auto feedback [redmine:#130949]
		- 20200508@Malcolm : search by setting name  [Redmine: #108739]
		- 20201013@Malcolm : change data type of @IsActive from TINYINT to BIT [Redmine: #130544]
		- 20230203@Tacy: Split 789y site [RedmineID: #182438]
	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT @SettingName = ISNULL(@SettingName,''), @IncludedSettingID = ISNULL(@IncludedSettingID,'')

	SELECT
			SettingName
		,	cs.SettingID
		,	CASE	WHEN @Lang='zh-TW' THEN ISNULL(cs.SettingValueCT,cs.SettingValue)
											WHEN @Lang='zh-CN' THEN ISNULL(cs.SettingValueCS,cs.SettingValue)
											ELSE cs.SettingValue
			END AS SettingValue
		,	cs.ExtraInfo
		,	cs.DisplayOrder
		,	cs.IsActive
		, 	m.SettingSource
	FROM	dbo.crmSetting AS cs WITH(NOLOCK)
		LEFT JOIN crmSettingMapping m WITH(NOLOCK) ON cs.SettingID = m.SettingID
	WHERE ((cs.SiteOffer = @UserRole OR @UserRole IS NULL) 
		  AND (cs.SettingName = @SettingName OR @SettingName = '')
		  AND (cs.IsActive = @IsActive OR @IsActive IS NULL)) 
		  OR (@IncludedSettingID <> '' AND ',' + @IncludedSettingID + ',' LIKE '%,' + CONVERT(VARCHAR(20),cs.SettingID) + ',%')
	ORDER BY cs.IsActive DESC, cs.SettingName, cs.DisplayOrder, cs.SettingID;
END;
GO