/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210520@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #153119]
*/
UPDATE crmNotificationTemplateContent WITH(ROWLOCK)
	SET Content = 'Dear Sir, Customer Support would like to inform the below announcement:

{content_en}

Thank you for your kind attention!'
WHERE NotificationTemplateId = 18 AND LanguageId = 50000