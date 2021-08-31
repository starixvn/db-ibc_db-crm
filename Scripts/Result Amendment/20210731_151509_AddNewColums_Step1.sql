/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/
/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/

-- Add Pic type
ALTER TABLE crmPIC
ADD PicType INT

DECLARE @MaxPicRole INT

SELECT @MaxPicRole = MAX(SettingID) FROM crmSetting WITH(NOLOCK) WHERE SettingName  = 'PICRole'

INSERT INTO dbo.crmSetting (SettingName, SettingID, SettingValue, DisplayOrder, IsActive, SiteOffer)
VALUES ('PICRole', @MaxPicRole + 1, 'Accountant', 6, 1, 2)
	  ,('PICType', 51000, 'Headline PIC', 1, 1, 2)
	  ,('PICType', 51001, 'Accounting PIC', 2, 1, 2)

DECLARE @HeadlinePic INT,  @AccountingPIC INT
SELECT 
	@HeadlinePic = CASE WHEN SettingValue = 'Headline PIC' THEN SettingID ELSE @HeadlinePic END
	,@AccountingPIC = CASE WHEN SettingValue = 'Accounting PIC' THEN SettingID ELSE @AccountingPIC END
FROM crmSetting WITH(NOLOCK)
WHERE SettingName = 'PICType'

UPDATE p
	SET p.PicType = @HeadlinePic
FROM crmPIC p WITH(ROWLOCK)
	INNER JOIN crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
WHERE s.SettingValue IN ('Boss','Staff','Partner','Assistant', 'PIC')

UPDATE p
	SET p.PicType = @AccountingPIC
FROM crmPIC p WITH(ROWLOCK)
	INNER JOIN crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
WHERE s.SettingValue IN ('Accountant')

INSERT INTO dbo.crmSettingRelation (SettingID, ParentID, DisplayOrder)
SELECT s.SettingID, @HeadlinePic, s.DisplayOrder
FROM crmSetting s WITH(NOLOCK)
WHERE s.SettingValue <> 'Accountant' AND SettingName = 'PICRole'

INSERT INTO dbo.crmSettingRelation (SettingID, ParentID, DisplayOrder)
SELECT s.SettingID, @AccountingPIC, s.DisplayOrder
FROM crmSetting s WITH(NOLOCK)
WHERE s.SettingValue  = 'Accountant' AND SettingName = 'PICRole'

INSERT INTO dbo.crmSettingRelation (SettingID, ParentID, DisplayOrder)
SELECT s.SettingID, 0, s.DisplayOrder
FROM crmSetting s WITH(NOLOCK)
WHERE s.SettingValue  = 'Accountant' AND SettingName = 'PICRole'

-- Add recipient type
INSERT INTO dbo.crmRecipientType 
SELECT n.v
FROM (
	VALUES ('Accounting PIC')
) AS n(v)
WHERE NOT EXISTS (SELECT 1 FROM dbo.crmRecipientType r WITH(NOLOCK) WHERE r.RecipientTypeName = 'Accounting PIC')