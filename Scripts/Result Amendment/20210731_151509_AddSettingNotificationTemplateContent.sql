/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/

DECLARE @NotificationTemplateID INT, @NotificationTypeID INT, @EN INT, @SC INT, @EN_SC INT, @TH INT, @YN INT

SELECT @NotificationTypeID = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Result Amendment Announcement'

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES 
	('Result Amendment Template - Sportsbook', @NotificationTypeID, 'Result Amendment Template - Sportsbook')
	,('Result Amendment Template - Virtual Sports 2', @NotificationTypeID, 'Result Amendment Template - Virtual Sports 2')
	,('Result Amendment Template - Virtual Sports', @NotificationTypeID, 'Result Amendment Template - Virtual Sports')
	,('Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @NotificationTypeID, 'Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)')
	,('Result Amendment Template - Outright - Uncalculation', @NotificationTypeID, 'Result Amendment Template - Outright - Uncalculation')
	,('Result Amendment Template - Accounting PIC
(Sportsbook)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Sportsbook)')
	,('Result Amendment Template - Accounting PIC
(Virtual Sports 2)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Virtual Sports 2)')
	,('Result Amendment Template - Accounting PIC
(Virtual Sports)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Virtual Sports)')
	,('Result Amendment Template - Accounting PIC
(Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game))', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game))')
	,('Result Amendment Template - Accounting PIC
(Outright - Uncalculation)', @NotificationTypeID, 'Result Amendment Template - Accounting PIC
(Outright - Uncalculation)')

DECLARE @Contents TABLE (NotificationTemplateName NVARCHAR(1000) , LanguageId INT, Value NVARCHAR(MAX))
SELECT 
	@EN		= CASE WHEN SettingValue = 'EN'		 THEN SettingID ELSE @EN	END,
	@SC		= CASE WHEN SettingValue = 'SC'		 THEN SettingID ELSE @SC	END,	
	@TH		= CASE WHEN SettingValue = 'TH'		 THEN SettingID ELSE @TH	END,
	@YN		= CASE WHEN SettingValue = 'YN'		 THEN SettingID ELSE @YN	END,
	@EN_SC	= CASE WHEN SettingValue = 'EN & SC' THEN SettingID ELSE @EN_SC END
FROM crmSetting WITH(NOLOCK)
WHERE SettingName = 'NotificationTemplateLanguage' AND IsActive = 1

INSERT INTO @Contents (NotificationTemplateName, LanguageId, Value)
VALUES --Result Amendment Template - Sportsbook
('Result Amendment Template - Sportsbook', @EN, N'Dear Sir, Customer Support would like to inform the below announcement:

Attn:[{sport_name_en}] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{league_name_en} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

Affected user: {affected_list}')
,('Result Amendment Template - Sportsbook', @SC,N'您好，客服部在此通知以下的通告：

请注意:[{sport_name_sc}] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{league_name_sc} - {date}] 已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

受影响会员: {affected_list}')
,('Result Amendment Template - Sportsbook', @EN_SC, N'Dear Sir, Customer Support would like to inform the below announcement:

Attn:[{sport_name_en}] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{league_name_en} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

您好，客服部在此通知以下的通告：

请注意:[{sport_name_sc}] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{league_name_sc} - {date}] 已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Affected user/受影响会员: {affected_list}')
,('Result Amendment Template - Sportsbook', @TH, N'เรียนลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบเกี่ยวกับประกาศด้านล่างนี้:

Attn:[{sport_name_th}] Due to wrong result displayed, the match between "{home_name_th} -vs- {away_name_th}" [{league_name_th} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

บัญชีสมาชิกที่ได้รับผลกระทบ: {affected_list}')
,('Result Amendment Template - Sportsbook', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo đến quý khách thông báo dưới đây:

Attn:[{sport_name_yn}] Due to wrong result displayed, the match between "{home_name_yn} -vs- {away_name_yn}" [{league_name_yn} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

Tài khoản bị ảnh hưởng: {affected_list}')
-- Result Amendment Template - Virtual Sports 2
,('Result Amendment Template - Virtual Sports 2', @EN, N'Dear Sir, Customer Support would like to inform the below announcement:

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{sport_name_en} ({round_match_info_en}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

Affected user: {affected_list}')
,('Result Amendment Template - Virtual Sports 2', @SC,N'您好，客服部在此通知以下的通告：

请注意:[Virtual Sports] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{sport_name_sc} ({round_match_info_sc}) - {date}]  已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

受影响会员: {affected_list}')
,('Result Amendment Template - Virtual Sports 2', @EN_SC, N'Dear Sir, Customer Support would like to inform the below announcement:

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{sport_name_en} ({round_match_info_en}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

您好，客服部在此通知以下的通告：

请注意:[Virtual Sports] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{sport_name_sc} ({round_match_info_sc}) - {date}]  已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Affected user/受影响会员: {affected_list}')
,('Result Amendment Template - Virtual Sports 2', @TH, N'เรียนลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบเกี่ยวกับประกาศด้านล่างนี้:

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_th} -vs- {away_name_th}" [{sport_name_th} ({round_match_info_th}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

บัญชีสมาชิกที่ได้รับผลกระทบ: {affected_list}')
,('Result Amendment Template - Virtual Sports 2', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo đến quý khách thông báo dưới đây:

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_yn} -vs- {away_name_yn}" [{sport_name_yn} ({round_match_info_yn}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

Tài khoản bị ảnh hưởng: {affected_list}')
-- Result Amendment Template - Virtual Sports
,('Result Amendment Template - Virtual Sports', @EN, N'Dear Sir, Customer Support would like to inform the below announcement:

Attn:[{sport_name_en}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

Affected user: {affected_list}')
,('Result Amendment Template - Virtual Sports', @SC,N'您好，客服部予通知以下的通告：

请注意:[{sport_name_sc}] 由于成绩结算有误, 注单: "" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!

受影响会员: {affected_list}')
,('Result Amendment Template - Virtual Sports', @EN_SC, N'Dear Sir, Customer Support would like to inform the below announcement:

Attn:[{sport_name_en}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

您好，客服部在此通知以下的通告：

请注意:[{sport_name_sc}] 由于成绩结算有误, 注单: "" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!

Affected user/受影响会员: {affected_list}')
,('Result Amendment Template - Virtual Sports', @TH, N'เรียนลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบเกี่ยวกับประกาศด้านล่างนี้:

Attn:[{sport_name_th}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

บัญชีสมาชิกที่ได้รับผลกระทบ: {affected_list}')
,('Result Amendment Template - Virtual Sports', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo đến quý khách thông báo dưới đây:

Attn:[{sport_name_yn}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

Tài khoản bị ảnh hưởng: {affected_list}')
--Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)
,('Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @EN, N'Dear Sir, Customer Support would like to inform the below announcement:

Attn:[{sport_name_en}] Due to technical error, all bets placed on [{sport_name_en} Event #{match_code} - {date}] has been re-settled as REFUNDED. 
Kindly double check your statement again. Sorry for the inconvenience caused! 

Affected user: {affected_list}')
,('Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @SC,N'您好，客服部在此通知以下的通告：

请注意:[{sport_name_sc}] 由于技术有误, 所有注单投注于 [{sport_name_sc} #{match_code} - {date}] 已重新结算为退款. 请重新检查您的帐目. 不便之处 敬请见谅!

受影响会员: {affected_list}')
,('Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @EN_SC, N'Dear Sir, Customer Support would like to inform the below announcement:

Attn:[{sport_name_en}] Due to technical error, all bets placed on [{sport_name_en} Event #{match_code} - {date}] has been re-settled as REFUNDED. 
Kindly double check your statement again. Sorry for the inconvenience caused! 

您好，客服部在此通知以下的通告：

请注意:[{sport_name_sc}] 由于技术有误, 所有注单投注于 [{sport_name_sc} #{match_code} - {date}] 已重新结算为退款. 请重新检查您的帐目. 不便之处 敬请见谅!

Affected user/受影响会员: {affected_list}')
,('Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @TH, N'เรียนลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบเกี่ยวกับประกาศด้านล่างนี้:

Attn:[{sport_name_th}] Due to technical error, all bets placed on [{sport_name_th} Event #{match_code} - {date}] has been re-settled as REFUNDED. 
Kindly double check your statement again. Sorry for the inconvenience caused! 

บัญชีสมาชิกที่ได้รับผลกระทบ: {affected_list}')
,('Result Amendment Template - Number Game
(Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thông báo dưới đây:

Attn:[{sport_name_yn}] Due to technical error, all bets placed on [{sport_name_yn} Event #{match_code} - {date}] has been re-settled as REFUNDED. 
Kindly double check your statement again. Sorry for the inconvenience caused! 

Tài khoản bị ảnh hưởng: {affected_list}')
--Result Amendment Template - Outright
,('Result Amendment Template - Outright - Uncalculation', @EN, N'Dear Sir, Customer Support would like to inform the below announcement:

{message_content_en}

Affected user: {affected_list}')
,('Result Amendment Template - Outright - Uncalculation', @SC,N'您好，客服部在此通知以下的通告：

{message_content_sc}

受影响会员: {affected_list}')
,('Result Amendment Template - Outright - Uncalculation', @EN_SC, N'Dear Sir, Customer Support would like to inform the below announcement:

{message_content_en}                     

您好，客服部在此通知以下的通告：

{message_content_sc}
   
Affected user/受影响会员: {affected_list}')
,('Result Amendment Template - Outright - Uncalculation', @TH, N'เรียนลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบเกี่ยวกับประกาศด้านล่างนี้:

{message_content_th}

บัญชีสมาชิกที่ได้รับผลกระทบ: {affected_list}')
,('Result Amendment Template - Outright - Uncalculation', @YN, N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thông báo dưới đây:

{message_content_yn}

Tài khoản bị ảnh hưởng: {affected_list}')
--Result Amendment Template - Accounting PIC (Sportsbook)
,('Result Amendment Template - Accounting PIC
(Sportsbook)', @EN, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{league_name_en} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[{sport_name_sc}] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{league_name_sc} - {date}] 已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Sportsbook)', @SC,N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{league_name_en} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[{sport_name_sc}] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{league_name_sc} - {date}] 已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Sportsbook)', @EN_SC, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{league_name_en} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[{sport_name_sc}] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{league_name_sc} - {date}] 已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Sportsbook)', @TH, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{league_name_en} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[{sport_name_sc}] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{league_name_sc} - {date}] 已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Sportsbook)', @YN, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{league_name_en} - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[{sport_name_sc}] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{league_name_sc} - {date}] 已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
-- Result Amendment Template - Accounting PIC (Virtual Sports 2)
,('Result Amendment Template - Accounting PIC
(Virtual Sports 2)', @EN, N'Hi, Kindly take note below announcement: 

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{sport_name_en} ({round_match_info_en}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[Virtual Sports] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{sport_name_sc} ({round_match_info_sc}) - {date}]  已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Virtual Sports 2)', @SC,N'Hi, Kindly take note below announcement: 

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{sport_name_en} ({round_match_info_en}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[Virtual Sports] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{sport_name_sc} ({round_match_info_sc}) - {date}]  已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Virtual Sports 2)', @EN_SC, N'Hi, Kindly take note below announcement: 

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{sport_name_en} ({round_match_info_en}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[Virtual Sports] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{sport_name_sc} ({round_match_info_sc}) - {date}]  已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Virtual Sports 2)', @TH, N'Hi, Kindly take note below announcement: 

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{sport_name_en} ({round_match_info_en}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[Virtual Sports] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{sport_name_sc} ({round_match_info_sc}) - {date}]  已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Virtual Sports 2)', @YN, N'Hi, Kindly take note below announcement: 

Attn:[Virtual Sports] Due to wrong result displayed, the match between "{home_name_en} -vs- {away_name_en}" [{sport_name_en} ({round_match_info_en}) - {date}] has been re-settled. 
The actual result is "{actual_result}" instead of "{wrong_result}". Kindly double check your statement again. Sorry for the inconvenience caused!

请注意:[Virtual Sports] 由于赛果显示错误, "{home_name_sc} -vs- {away_name_sc}" [{sport_name_sc} ({round_match_info_sc}) - {date}]  已重新结算. 正确之赛果为 "{actual_result}" 而不是 "{wrong_result}". 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
-- Result Amendment Template - Accounting PIC (Virtual Sports)
,('Result Amendment Template - Accounting PIC
(Virtual Sports)', @EN, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于成绩结算有误, 注单: "" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Virtual Sports)', @SC,N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于成绩结算有误, 注单: "" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Virtual Sports)', @EN_SC, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于成绩结算有误, 注单: "" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Virtual Sports)', @TH, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于成绩结算有误, 注单: "" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Virtual Sports)', @YN, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to the wrong calculation, bet ID: "" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于成绩结算有误, 注单: "" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
--Result Amendment Template - Accounting PIC (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)
,('Result Amendment Template - Accounting PIC
(Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game))', @EN, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to technical error, all bets placed on [{sport_name_en} Event #{match_code} - {date}] has been re-settled as REFUNDED. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于技术有误, 所有注单投注于 [{sport_name_sc} #{match_code} - {date}] 已重新结算为退款. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game))', @SC,N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to technical error, all bets placed on [{sport_name_en} Event #{match_code} - {date}] has been re-settled as REFUNDED. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于技术有误, 所有注单投注于 [{sport_name_sc} #{match_code} - {date}] 已重新结算为退款. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game))', @EN_SC, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to technical error, all bets placed on [{sport_name_en} Event #{match_code} - {date}] has been re-settled as REFUNDED. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于技术有误, 所有注单投注于 [{sport_name_sc} #{match_code} - {date}] 已重新结算为退款. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game))', @TH, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to technical error, all bets placed on [{sport_name_en} Event #{match_code} - {date}] has been re-settled as REFUNDED. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于技术有误, 所有注单投注于 [{sport_name_sc} #{match_code} - {date}] 已重新结算为退款. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
,('Result Amendment Template - Accounting PIC
(Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game))', @YN, N'Hi, Kindly take note below announcement: 

Attn:[{sport_name_en}] Due to technical error, all bets placed on [{sport_name_en} Event #{match_code} - {date}] has been re-settled as REFUNDED. Kindly double check your statement again. Sorry for the inconvenience caused! 

请注意:[{sport_name_sc}] 由于技术有误, 所有注单投注于 [{sport_name_sc} #{match_code} - {date}] 已重新结算为退款. 请重新检查您的帐目. 不便之处 敬请见谅!

Thank you')
--Result Amendment Template - Accounting PIC (Outright - Uncalculation)
,('Result Amendment Template - Accounting PIC
(Outright - Uncalculation)', @EN, N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')
,('Result Amendment Template - Accounting PIC
(Outright - Uncalculation)', @SC,N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')
,('Result Amendment Template - Accounting PIC
(Outright - Uncalculation)', @EN_SC, N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')
,('Result Amendment Template - Accounting PIC
(Outright - Uncalculation)', @TH, N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')
,('Result Amendment Template - Accounting PIC
(Outright - Uncalculation)', @YN, N'Hi, Kindly take note below announcement: 

{message_content_en}

{message_content_sc}

Thank you')


INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
SELECT nt.NotificationTemplateId, c.LanguageId, c.Value
FROM @Contents c
	INNER JOIN dbo.crmNotificationTemplate nt WITH(NOLOCK) ON nt.NotificationTemplateName = c.NotificationTemplateName 

