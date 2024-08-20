/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created by Roy@20240816
	Run at DBCRM@MessageNotification
	Task: Add new 2 Services into [Job Setting Management]
*/

USE MessageNotification
GO

INSERT INTO SystemSetting (
	VID
	,VName
	,VValue
	,DataType
	,Remark
)
VALUES (21,'AlertService', 'Done', 'String', 'Done, Running')
	,(22,'UAT_AlertService', 'Done', 'String', 'Done, Running')
GO
