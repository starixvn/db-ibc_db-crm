/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

USE bodb_CRM
GO

/*
	Created: 20210728@Malcolm
	DB: DBCRM.bodb_CRM
	Task:  update date
	Revisions:
		- 20210728@Malcolm:  update template [RedmineID: #157303]
*/

UPDATE s
	set s.Value = '<root>
			<r IsTest="0" NotificationTemplateID="1" NotificationTypeID="1" Type="1">
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50000" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50001" />
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{TH Announcement}" LanguageId="50003" />
				<TemplateRequiredParam Value="{YN Announcement}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50000" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50001" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50003" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50002" />
			</r>
			<r IsTest="0" NotificationTemplateID="19" NotificationTypeID="11" Type="2">
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50000" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50001" />
				<TemplateRequiredParam Value="{EN Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{SC Announcement}" LanguageId="50002" />
				<TemplateRequiredParam Value="{TH Announcement}" LanguageId="50003" />
				<TemplateRequiredParam Value="{YN Announcement}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50000" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50001" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50003" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50004" />
				<TemplateRequiredParam Value="{Affected List}" LanguageId="50002" />
			</r>
		</root>'
from SystemSetting s WITH(ROWLOCK)
WHERE s.SettingName = 'NotificationTemplate' AND s.ServiceName = 'ChatBot - AbnormalBets'

