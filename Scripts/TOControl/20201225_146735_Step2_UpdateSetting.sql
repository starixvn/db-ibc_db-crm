/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201225@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Setting [RedmineId : #146735]
*/
--Step2-----
--Update Setting
DECLARE @NotificationTemplateId INT, @SystemId INT, @NotificationTypeId INT

SELECT @NotificationTemplateId = NotificationTemplateId FROM dbo.crmNotificationTemplate WITH(NOLOCK) WHERE NotificationTemplateName = 'Turnover Control Template'

SELECT @SystemId = s.SystemId FROM dbo.crmSystem s WITH(NOLOCK) WHERE s.SystemName = 'Customer Management'

SELECT @NotificationTypeId = NotificationTypeId FROM dbo.crmNotificationType  WITH(NOLOCK) WHERE NotificationTypeName = 'Turnover Control Announcement' AND SystemId = @SystemId

DECLARE @MaxLogId BIGINT 

SELECT @MaxLogId = LastLogId FROM OPENQUERY (DBCUST, 'SELECT Max(logid) AS LastLogId FROM CustDB.dbo.TOControl_Setting_History')

INSERT INTO dbo.SystemSetting (SettingName, Value ,ServiceName)
VALUES ('LastLogID', CONVERT(VARCHAR(20), @MaxLogId), 'ChatBot - TOControl')
	,('LastLogIdUAT', CONVERT(VARCHAR(20), @MaxLogId), 'ChatBot - TOControl')
	,('IncludeUUSCurrency', '1', 'ChatBot - TOControl')
	,('BatchSize', '10', 'ChatBot - TOControl')
	,('JobStatus', 'Completed', 'ChatBot - TOControl')
	,('JobStatusUAT', 'Completed', 'ChatBot - TOControl')
	,('ServiceFlag', '1', 'ChatBot - TOControl')
	,('NotificationTemplate', '1', 'ChatBot - TOControl')

DECLARE @NotificationTemplate NVARCHAR(MAX)
= N'<root>
  <r IsTest="1" NotificationTemplateID="'+ CONVERT(NVARCHAR(MAX), @NotificationTemplateId) +'" NotificationTypeID="'+ CONVERT(NVARCHAR(MAX), @NotificationTypeID)+'">
	<TemplateRequiredParam Value="{event_outstanding}" LanguageId="50000" Frequency="1"/>
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50001" Frequency="1"/>
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50003" Frequency="1"/>
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50004" Frequency="1"/>
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50002" Frequency="2"/>
	<TemplateRequiredParam Value="{currency_name}" LanguageId="50000" Frequency="1"/>
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50001" Frequency="1"/>
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50003" Frequency="1"/>
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50004" Frequency="1"/>
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50002" Frequency="2"/>
	<TemplateRequiredParam Value="{SMA_username}" LanguageId="50000" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50001" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50003" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50004" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50002" Frequency="2"/>
	<TemplateRequiredParam Value="{SMA_level_en}" LanguageId="50000" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_level_sc}" LanguageId="50001" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_level_en}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_level_sc}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_level_th}" LanguageId="50003" Frequency="1"/>
    <TemplateRequiredParam Value="{SMA_level_yn}" LanguageId="50004" Frequency="1"/>
	<TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1"/>
    <TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1"/>
    <TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{sport_name_th}" LanguageId="50003" Frequency="1"/>
    <TemplateRequiredParam Value="{sport_name_yn}" LanguageId="50004" Frequency="1"/>
	<TemplateRequiredParam Value="{league_name_en}" LanguageId="50000" Frequency="1"/>
    <TemplateRequiredParam Value="{league_name_sc}" LanguageId="50001" Frequency="1"/>
    <TemplateRequiredParam Value="{league_name_en}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{league_name_sc}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{league_name_th}" LanguageId="50003" Frequency="1"/>
    <TemplateRequiredParam Value="{league_name_yn}" LanguageId="50004" Frequency="1"/>
	<TemplateRequiredParam Value="{home_name_en}" LanguageId="50000" Frequency="1"/>
    <TemplateRequiredParam Value="{home_name_sc}" LanguageId="50001" Frequency="1"/>
    <TemplateRequiredParam Value="{home_name_en}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{home_name_sc}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{home_name_th}" LanguageId="50003" Frequency="1"/>
    <TemplateRequiredParam Value="{home_name_yn}" LanguageId="50004" Frequency="1"/>
	<TemplateRequiredParam Value="{away_name_en}" LanguageId="50000" Frequency="1"/>
    <TemplateRequiredParam Value="{away_name_sc}" LanguageId="50001" Frequency="1"/>
    <TemplateRequiredParam Value="{away_name_en}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{away_name_sc}" LanguageId="50002" Frequency="1"/>
    <TemplateRequiredParam Value="{away_name_th}" LanguageId="50003" Frequency="1"/>
    <TemplateRequiredParam Value="{away_name_yn}" LanguageId="50004" Frequency="1"/>
  </r>
</root>'

UPDATE s
	 SET Value = @NotificationTemplate
FROM SystemSetting s
WHERE s.ServiceName = 'ChatBot - TOControl' and s.SettingName = 'NotificationTemplate'