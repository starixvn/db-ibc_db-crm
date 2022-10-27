/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221027@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Remark [RedmineId : #179240]
*/
USE bodb_CRM
GO

ALTER TABLE crmConversationGroup
ADD IsDeleted BIT CONSTRAINT DFF_crmConversationGroup_IsDeleted DEFAULT(0) WITH VALUES

INSERT INTO crmLogActionType (ActionTypeID, ActionTypeName)
VALUES (5, 'Chat Type Mapping')

UPDATE crmLogAction WITH(ROWLOCK)
	SET ActionTypeID = 5
WHERE SpName IN ('Acc_CRM_ChatBot_ChatTypeMapping_Ins','Acc_CRM_ChatBot_ChatTypeMapping_Upd','Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd','Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd')

INSERT INTO crmLogAction (ActionID, SPName, ActionNameEN, IsInternal, ExcludedForCn88, ActionTypeID)
VALUES (1011, 'Acc_CRM_ChatBot_ConversationGroup_Del', 'Delete conversation group', 0, 1, 5)

