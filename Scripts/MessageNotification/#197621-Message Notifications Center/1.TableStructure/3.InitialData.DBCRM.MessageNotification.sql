/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created by Roy@20231213
	Run at DBCRM@MessageNotification
	Task: Insert i nitial data for workflow
*/
USE [MessageNotification]
GO

/***** NotiStatus ****/
TRUNCATE TABLE NotiStatus
INSERT INTO NotiStatus (Status)
VALUES ('Unknown')
	,('Retrieving')
	,('Successfully Retrieved')
	,('Failed to Retrieve')
	,('Generating')
	,('Successfully Generated')
	,('Failed to Generate')
	,('New')
	,('Ready to Send')
	,('Draft')
	,('Cancelled')
	,('Sending')
	,('Sent')
	,('Failed to Send')
	,('Active')
	,('Inactive')

/***** LogAction ****/
TRUNCATE TABLE LogAction
INSERT INTO LogAction (ActName)
VALUES ('Unknown')

/***** SystemSetting ****/
TRUNCATE TABLE SystemSetting
INSERT INTO SystemSetting (
	VID
	,VName
	,VValue
	,Remark
)
VALUES (1, 'ScanBackHour', '24', 'scan back from current to pull SettlementResultHistory')
	,(2,'Executor', '10278938', 'ID of StarixIT')
	,(3,'NeedReviewBySport', '50', 'With these sports, need to review notification before push to Msg/MsgTarget')
	
	,(4,'Process_CaptureData', 'Done', 'Done, Running')
	,(5,'Process_GenerateNoti', 'Done', 'Done, Running')
	,(6,'Process_PushNoti', 'Done', 'Done, Running')
	
	,(7,'ProcessUAT_CaptureData', 'Done', 'Done, Running')
	,(8,'ProcessUAT_GenerateNoti', 'Done', 'Done, Running')
	,(9,'ProcessUAT_PushNoti', 'Done', 'Done, Running')
	
	,(10,'UATMode', 'OFF', 'Turn ON/OFF UATMode; If UATMode = OFF, 1.PRD handle all data 2.Write error log only; If UATMode = ON, 1.PRD handle REAL data only 2.UAT handle REAL TEST (test matches) 3.Write detail log')
	,(11,'Retrieving_WaitSec', '30', 'Change Status [Retrieving] -> [Successfully Retrieved] IF the SessionID keep Retrieving over this configuration')
	,(12,'NeedReviewContent', '1', '1=Yes; 0=No; Need review message content before push to DBMSG')

/***** NotiTemplate ****/
TRUNCATE TABLE NotiTemplate

DECLARE @StarixIT INT
SELECT @StarixIT = TRY_CONVERT(INT, VValue)
FROM SystemSetting WITH (NOLOCK)
WHERE VID = 2 --ID of StarixIT

INSERT INTO NotiTemplate (
	TemplateName
	,Content_en
	,Content_ch
	,Content_cs
	,RequiredParams
	,CreatorID
	,LastModifiedBy
	,Remark
)
VALUES (
		'Cricket Result Amendment - Wrong Calculation - Amended <= 2 - TXT template'
		,N'Attn:[{sport_name}] Due to {affected_result_name} wrong calculation, all bets place on {match_info} as a result bet ID: "@@" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於 {affected_result_name} 成績結算有誤, 所有注單投注於 {match_info} 注單: "@@" 已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒!'
		,N'请注意:[{sport_name}] 由于 {affected_result_name} 成绩结算有误, 所有注单投注于 {match_info} 注單: "@@" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{affected_result_name},{match_info}'
		,@StarixIT
		,@StarixIT
		,'Generate Notification for Msg with text format - CAL to Refund or Refund to CAL with Amended Result is 1 or 2'
	)
	,(
		'Cricket Result Amendment - Wrong Calculation - Amended > 2 - TXT template'
		,N'Attn:[{sport_name}] Due to wrong calculation, all bets place on {match_info} has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於成績結算有誤, 所有注單投注於 {match_info} 注單: "@@"已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒!'		
		,N'请注意:[{sport_name}] 由于成绩结算有误, 所有注单投注于 {match_info} 注單: "@@" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{match_info}'
		,@StarixIT
		,@StarixIT
		,'Generate Notification for Msg with text format - CAL to Refund or Refund to CAL with Amended Result is more than 2'
	)
	,(
		'Cricket Result Amendment - Wrong Result - Amended = 1 - TXT template'
		,N'Attn:[{sport_name}] Due to {affected_result_name} wrong result displayed, the match between {match_info} as a result bet ID: "@@" has been re-settled. The actual result is "{new_value}" instead of "{old_value}". Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於 {affected_result_name} 賽果顯示錯誤, {match_info} 注單: "@@" 已重新結算. 正確之賽果為 "{new_value}" 而不是 "{old_value}". 請重新檢查您的帳目. 不便之處 敬請見諒!'
		,N'请注意:[{sport_name}] 由于 {affected_result_name} 赛果显示错误, {match_info} 注單: "@@" 已重新结算. 正确之赛果为 "{new_value}" 而不是 "{old_value}". 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{affected_result_name},{match_info},{new_value},{old_value}'
		,@StarixIT
		,@StarixIT
		,'Generate Notification for Msg with text format - CAL to CAL with Amended Result is 1'
	)
	,(
		'Cricket Result Amendment - Wrong Result - Amended = 2 - TXT template'
		,N'Attn:[{sport_name}] Due to {affected_result_name}_list wrong result displayed, the match between {match_info} as a result bet ID: "@@" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於 {affected_result_name}_list 賽果顯示錯誤, {match_info} 注單: "@@" 已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒! '
		,N'请注意:[{sport_name}] 由于 {affected_result_name}_list 赛果显示错误, {match_info} 注單: "@@" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{affected_result_name},{match_info}'
		,@StarixIT
		,@StarixIT
		,'Generate Notification for Msg with text format - CAL to CAL with Amended Result is 2'
	)
	,(
		'Cricket Result Amendment - Wrong Result - Amended > 2 - TXT template'
		,N'Attn:[{sport_name}] Due to wrong result displayed, the match between {match_info} as a result bet ID: "@@" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於賽果顯示錯誤, {match_info} 注單: "@@" 已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒!'
		,N'请注意:[{sport_name}] 由于赛果显示错误, {match_info} 注單: "@@" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{match_info}'
		,@StarixIT
		,@StarixIT
		,'Generate Notification for Msg with text format - CAL to CAL with Amended Result is more than 2'
	)
	,(
		'Cricket Result Amendment - Notification for LAP - HTML template'
		,N'<b>Dear Valued Customers,</b><br/><br/>Please be informed that the match between "{match_name}" [{league_name} - {event_date}], result has been amended. Please refer to below for more information:<br/><br/><b>English Message:-</b><br/>{notification}<br/><br/><b>Settlement log:</b><br/><b>(System Time)</b><br/>{cal_time}<br/>{recal_time}<br/><br/><b style="color:red">Kindly refer to the attached file for those affected customers & tickets.</b><br/><br/>Sorry for the inconvenience caused and thank you for your kind attention!<br/><br/><b>Best Regards,<br/>Customer Service Team</b>'
		,NULL AS Content_ch
		,N'<b>亲爱的客户,</b><br/><br/>请注意, 赛事 "{match_name}" [{league_name} - {event_date}], 赛果已重新结算。有关详情，请参考以下资讯：<br/><br/><b>中文信息:-</b><br/>{notification}<br/><br/><b>结算日志:</b><br/><b>(系统时间)</b><br/>{cal_time}<br/>{recal_time}<br/><br/><b style="color:red">有关受影响的会员和注单请参阅附件。</b><br/><br/>不便之处, 敬请见谅。谢谢!<br/>'
		,N'{match_name},{league_name},{event_date},{notification},{cal_time},{recal_time}'
		,@StarixIT
		,@StarixIT
		,'Generate Notification for LAP with HTML format - {cal_time} can be multi rows'
	)