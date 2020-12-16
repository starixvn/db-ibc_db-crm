/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201216@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update IncludeUUSCurrency and Istest for CWL and abnormalbets [RedmineId : #144265]
*/

DECLARE @IncludeUUSCurrency_AbnormalBets VARCHAR(20) = '1', 
		@IncludeUUSCurrency_CWL			 VARCHAR(20) = '1',
		@IsTest_AbnormalBets			 VARCHAR(MAX) = '0',
		@IsTest_CWL						 VARCHAR(MAX) = '0'

--Update IncludeUUSCurrency
UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = @IncludeUUSCurrency_AbnormalBets
WHERE ServiceName = 'ChatBot - AbnormalBets'
	AND SettingName = 'IncludeUUSCurrency'

UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = @IncludeUUSCurrency_CWL
WHERE ServiceName = 'ChatBot - CWL'
	AND SettingName = 'IncludeUUSCurrency'

--Update IsTest
DECLARE @XML NVARCHAR(MAX) 
SELECT @XML = '<root> 
					<r IsTest="' + @IsTest_AbnormalBets +'" NotificationTemplateID="1" NotificationTypeID="1">          
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
				</root>'--	ChatBot - AbnormalBets

UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = @XML
WHERE ServiceName = 'ChatBot - AbnormalBets' AND SettingName = 'NotificationTemplate'


SELECT @XML = ''

SELECT @XML = '<root>
				<r IsTest="' + @IsTest_CWL +'" GroupIds="0" LevelIds="1,2" NotificationTemplateID="3" NotificationTypeID="3">
					<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" Frequency="1"/>
				</r>
				<r IsTest="' + @IsTest_CWL +'" GroupIds="0" LevelIds="3" NotificationTemplateID="4" NotificationTypeID="3">
					<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" Frequency="1"/>
				</r>
				<r IsTest="' + @IsTest_CWL +'" GroupIds="0" LevelIds="101" NotificationTemplateID="5" NotificationTypeID="3">
					<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" Frequency="1"/>
				</r>
				<r IsTest="' + @IsTest_CWL +'" GroupIds="0" LevelIds="102" NotificationTemplateID="6" NotificationTypeID="3">
					<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_en}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_en}" LanguageId="50002" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_sc}" LanguageId="50002" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_th}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{product_name_yn}" LanguageId="50004" Frequency="1"/>
				</r>
				<r IsTest="' + @IsTest_CWL +'" GroupIds="17" LevelIds="1" NotificationTemplateID="7" NotificationTypeID="3">
					<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
				</r>
				<r IsTest="' + @IsTest_CWL +'" GroupIds="18" LevelIds="3" NotificationTemplateID="7" NotificationTypeID="3">
					<TemplateRequiredParam Value="{player_username}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_username}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_wl_amount}" LanguageId="50004" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50000" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50001" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50002" Frequency="2"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50003" Frequency="1"/>
					<TemplateRequiredParam Value="{player_currency}" LanguageId="50004" Frequency="1"/>
				</r>
			</root>'

UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = @XML
WHERE ServiceName = 'ChatBot - CWL' AND SettingName = 'NotificationTemplate'

