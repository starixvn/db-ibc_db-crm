/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

USE bodb_CRM
GO

/*
	Created: 20201009@Malcolm
	DB: DBCRM.bodb_CRM
	Task:  update date
	Revisions:
		- 20201009@Malcolm:  update log action [RedmineID: #130544]
*/

INSERT INTO dbo.crmLogActionType(ActionTypeID, ActionTypeName)
VALUES(4, 'Headline Notification')

INSERT INTO dbo.crmLogAction(ActionID,SPName,ActionNameEN,IsInternal,ExcludedForCn88,ActionTypeID)
VALUES(1001, 'Acc_CRM_ChatBot_NotificationType_Ins','Insert Notification Type',0,1,4)
	,(1002,'Acc_CRM_ChatBot_NotificationType_Upd','Update Notification Type',0,1,4)
	,(1003	,'Acc_CRM_ChatBot_NotificationType_Del','Delete Notification Type',0,1,4)
	,(1004,'Acc_CRM_ChatBot_NotificationTemplate_Ins','Insert Notification Template',0,1,4)
	,(1005,'Acc_CRM_ChatBot_NotificationTemplate_Upd','Update Notification Template',0,1,4)
	,(1006,'Acc_CRM_ChatBot_NotificationTemplate_Del','Remove Notificaton Template',0,1,4)
	,(1007,	'Acc_CRM_ChatBot_ChatTypeMapping_Ins','Insert Chat Type Mapping',0,1,4)
	,(1008,	'Acc_CRM_ChatBot_ChatTypeMapping_Upd','Update Chat Type Mapping',0,1,4)
	,(1009,'Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd','Update Chat Type Mapping Status',0,1,4)