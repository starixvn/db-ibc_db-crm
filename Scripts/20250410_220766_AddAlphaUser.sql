/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
    Created: 20250410@Virgil
    DB: DBCRM-bodb_CRM
    Task: CRM - Manage SMA Feedback in effective way [RedmineID: #220766]
	Note: Create user login from Alpha site
*/

USE [bodb_CRM]
GO

CREATE USER [wsv_alp] FOR LOGIN [wsv_alp]
CREATE USER [wsv_alpv] FOR LOGIN [wsv_alpv]

GRANT EXECUTE ON dbo.Acc_CRM_SettingGetRelationBySettingName_xtest TO wsv_alp;
GRANT EXECUTE ON dbo.Acc_CRM_SettingGetRelationBySettingName_xtest TO wsv_alpv;

GO