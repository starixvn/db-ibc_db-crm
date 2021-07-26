/*<info serverAlias="DBCRM-bodb_CRM"></info>*/
/*
	Created: 20210726@Malcolm
	DB: DBCRM-bodb_CRM
	Task: add Settings [RedmineId : #151509]
*/

INSERT INTO dbo.crmSetting (SettingName,SettingID,SettingValue,DisplayOrder,IsActive,SiteOffer)
VALUES  ('PICType', 51000, 'Headline PIC', 1, 1, 2)
		,('PICType', 51001, 'Accounting PIC', 2, 1, 2)
		,('PICRole', 48005, 'Accountant', 6, 1, 2)

INSERT INTO dbo.crmSettingRelation (SettingID, ParentID, DisplayOrder)
VALUES 
	(51000, 0, 0) -- Headline PIC
	,(51001, 0, 0) -- Accounting PIC	
	,(48001, 51000, 1) -- Boss
	,(48002, 51000, 2) -- Staff
	,(48000, 51000, 3) -- PIC
	,(48003, 51000, 4) -- Partner
	,(48004, 51000, 5) -- Assistant
	,(48005, 51001, 6) -- Accountant

INSERT INTO dbo.crmRecipientType (RecipientTypeName) 
VALUES ('Accounting PIC')
	