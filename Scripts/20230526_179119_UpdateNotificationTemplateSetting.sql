/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20200810@Malcolm
	Task : Update Setting for To Control Service [RedmineID : #179119]
	DB: DBCRM/bodb_CRM
	
*/

DECLARE @XML NVARCHAR(MAX)
= '<root>
  <r IsTest="0" NotificationTemplateID="17" NotificationTypeID="9">
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50000" Frequency="1" />
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50001" Frequency="1" />
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50003" Frequency="1" />
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50004" Frequency="1" />
    <TemplateRequiredParam Value="{event_outstanding}" LanguageId="50002" Frequency="2" />
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50000" Frequency="1" />
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50001" Frequency="1" />
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50003" Frequency="1" />
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50004" Frequency="1" />
    <TemplateRequiredParam Value="{currency_name}" LanguageId="50002" Frequency="2" />
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50000" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50001" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50003" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50004" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_username}" LanguageId="50002" Frequency="2" />
    <TemplateRequiredParam Value="{SMA_level_en}" LanguageId="50000" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_level_sc}" LanguageId="50001" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_level_en}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_level_sc}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_level_th}" LanguageId="50003" Frequency="1" />
    <TemplateRequiredParam Value="{SMA_level_en}" LanguageId="50004" Frequency="1" />
    <TemplateRequiredParam Value="{sport_name_en}" LanguageId="50000" Frequency="1" />
    <TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50001" Frequency="1" />
    <TemplateRequiredParam Value="{sport_name_en}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{sport_name_sc}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{sport_name_th}" LanguageId="50003" Frequency="1" />
    <TemplateRequiredParam Value="{sport_name_yn}" LanguageId="50004" Frequency="1" />
    <TemplateRequiredParam Value="{league_name_en}" LanguageId="50000" Frequency="1" />
    <TemplateRequiredParam Value="{league_name_sc}" LanguageId="50001" Frequency="1" />
    <TemplateRequiredParam Value="{league_name_en}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{league_name_sc}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{league_name_th}" LanguageId="50003" Frequency="1" />
    <TemplateRequiredParam Value="{league_name_yn}" LanguageId="50004" Frequency="1" />
    <TemplateRequiredParam Value="{home_name_en}" LanguageId="50000" Frequency="1" />
    <TemplateRequiredParam Value="{home_name_sc}" LanguageId="50001" Frequency="1" />
    <TemplateRequiredParam Value="{home_name_en}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{home_name_sc}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{home_name_th}" LanguageId="50003" Frequency="1" />
    <TemplateRequiredParam Value="{home_name_yn}" LanguageId="50004" Frequency="1" />
    <TemplateRequiredParam Value="{away_name_en}" LanguageId="50000" Frequency="1" />
    <TemplateRequiredParam Value="{away_name_sc}" LanguageId="50001" Frequency="1" />
    <TemplateRequiredParam Value="{away_name_en}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{away_name_sc}" LanguageId="50002" Frequency="1" />
    <TemplateRequiredParam Value="{away_name_th}" LanguageId="50003" Frequency="1" />
    <TemplateRequiredParam Value="{away_name_yn}" LanguageId="50004" Frequency="1" />
  </r>
</root>'



UPDATE SystemSetting
	SET Value = @XML
WHERE ServiceName = 'ChatBot - TOControl' AND SettingName = 'NotificationTemplate' 