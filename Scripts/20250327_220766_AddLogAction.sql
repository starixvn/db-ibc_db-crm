/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/
/*
	Created: 20250327@Virgil
	Task: CRM - Manage SMA Feedback in effective way [Redmine #196012]
	DB: DBCRM-bodb_CRM
*/

USE [bodb_CRM]
GO

INSERT INTO dbo.crmLogAction (ActionID, SPName, ActionNameEN, IsInternal, ExcludedForCn88, ActionTypeID)
VALUES (1022, 'Acc_CRM_SMAFeedbackInfoUpd', 'Update SMA feedback info', 0, NULL, NULL)