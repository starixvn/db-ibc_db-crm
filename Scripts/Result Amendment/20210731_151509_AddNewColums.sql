/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/

ALTER TABLE crmPIC
ADD Type INT

DECLARE @HeadlinePic INT,  @AccountingPIC INT
SELECT 
	@HeadlinePic = CASE WHEN SettingValue = 'Headline PIC' THEN SettingID ELSE @HeadlinePic END
	,@AccountingPIC = CASE WHEN SettingValue = 'Accounting PIC' THEN SettingID ELSE @AccountingPIC END
FROM crmSetting WITH(NOLOCK)
WHERE SettingName = 'PICType'

UPDATE p
	SET p.Type = @HeadlinePic
FROM crmPIC p WITH(ROWLOCK)
	INNER JOIN crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
WHERE s.SettingValue IN ('Boss','Staff','Partner','Assistant', 'PIC')

UPDATE p
	SET p.Type = @AccountingPIC
FROM crmPIC p WITH(ROWLOCK)
	INNER JOIN crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
WHERE s.SettingValue IN ('Accountant')


-- Add Pic type