/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20221114@Malcolm
	Task : Grant permission for bodbAdminNet
	DB: DBCRM/bodb_CRM

*/
GRANT SELECT ON crmUserLog_RunSP TO bodbAdminNet; 
GRANT SELECT ON crmLogAction TO bodbAdminNet; 
