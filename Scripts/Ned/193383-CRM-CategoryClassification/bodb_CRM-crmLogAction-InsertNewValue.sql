/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20230922@Ned.Le
DB: DBCRM.bodb_CRM
Task: Insert new value to table crmLogAction
*/

USE bodb_CRM
GO

INSERT INTO dbo.crmLogAction (ActionID, SPName, ActionNameEN, IsInternal, ExcludedForCn88, ActionTypeID) VALUES
(312, 'Acc_CRM_CategoryClassificationUpd', 'Update remark of category classification', 0, NULL, NULL),
(313, 'Acc_CRM_CategoryClassificationDel', 'Remove remark of category classification', 0, NULL, NULL)
GO