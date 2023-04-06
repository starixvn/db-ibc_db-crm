/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221222@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Add logaction [RedmineId : #179118]
*/

INSERT INTO dbo.crmLogActionType (ActionTypeID, ActionTypeName)
VALUES (6, 'Announcement')

INSERT INTO dbo.crmLogAction (ActionID, SPName, ActionNameEN, IsInternal, ExcludedForCn88, ActionTypeID)
VALUES (1012, 'Acc_CRM_ChatBot_AnnouncementStatus_Upd', 'Update annoucement status', 0, 1, 6)
		,(1013, 'Acc_CRM_ChatBot_Announcement_Ins', 'Insert new annoucement', 0, 1, 6)
		,(1014, 'Acc_CRM_ChatBot_Announcement_Upd', 'Update a annoucement', 0, 1, 6)

GO

ALTER TABLE crmUserLog_RunSP
ALTER COLUMN IP VARCHAR(45)
GO