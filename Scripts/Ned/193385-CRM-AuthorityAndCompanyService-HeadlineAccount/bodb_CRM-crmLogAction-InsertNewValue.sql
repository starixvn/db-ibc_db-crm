/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240220@Ned.Le
DB: DBCRM.bodb_CRM
Task: 1. Change data type for column SPName from VARCHAR(50) to VARCHAR(200)
      2. Insert new value to table crmLogAction
*/

USE bodb_CRM
GO

-- 1. Change data type for column SPName from VARCHAR(50) to VARCHAR(200)
ALTER TABLE dbo.crmLogAction ALTER COLUMN SPName VARCHAR(200)
GO

-- 2. Insert new value to table crmLogAction
DELETE l
FROM dbo.crmLogAction l WITH (ROWLOCK, UPDLOCK)
WHERE ActionID IN (109, 110, 111, 112, 207, 208)
GO

INSERT INTO dbo.crmLogAction (ActionID, SPName, ActionNameEN, IsInternal, ExcludedForCn88, ActionTypeID) VALUES
(109, 'Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo', 'Update Communication Tool', 0, NULL, NULL),
(110, 'Acc_CRM_NewAccDetail_UpdHeadlineCompanyService', 'Update Company Service', 0, NULL, NULL),
(111, 'Acc_CRM_NewAccDetail_SyncHeadlineStaffAndAuthority', 'Sync Headline Staff and Authority', 0, NULL, NULL),
(112, 'Acc_CRM_NewAccDetail_UpdHeadlineStaffAndAuthority', 'Update Headline Staff and Authority', 0, NULL, NULL),
(207, 'Acc_CRM_NewManualFeedback_FeedbackIns', 'New Mechanism - Insert Feedback Info', 0, NULL, NULL),
(208, 'Acc_CRM_NewManualFeedback_FeedbackUpd', 'New Mechanism - Update Feedback Info', 0, NULL, NULL)
GO