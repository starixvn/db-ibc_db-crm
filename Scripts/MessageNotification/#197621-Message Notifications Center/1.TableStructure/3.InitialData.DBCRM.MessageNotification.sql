/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created by Roy@20231213
	Run at DBCRM@MessageNotification
	Task: Insert initial data for workflow
*/
USE [MessageNotification]
GO

/***** NotiStatus ****/
TRUNCATE TABLE NotiStatus
INSERT INTO NotiStatus (
	StatusID
	,Status
)
VALUES (1, 'Unknown')
	,(2, 'Retrieving')
	,(3, 'Successfully Retrieved')
	,(4, 'Failed to Retrieve')
	,(5, 'Generating')
	,(6, 'Successfully Generated')
	,(7 ,'Failed to Generate')
	,(8, 'New')
	-- ,(9, 'Ready to Send')
	,(10, 'Draft')
	,(11, 'Cancelled')
	,(12, 'Sending')
	,(13, 'Sent')
	,(14, 'Failed to Send')
	,(15, 'Active')
	,(16, 'Inactive')

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
	,DataType
	,Remark
)
VALUES (1, 'ScanBackHour', '24', 'Int32', 'scan back from current to pull SettlementResultHistory')
	,(2,'Executor', '10278938', 'Int32', 'ID of StarixIT')
	,(3,'IgnoreReviewContentBySport', '', 'String', 'With these sports, IGNORE review notification before push to Msg/MsgTarget')
	
	,(4,'Process_CaptureData', 'Done', 'String', 'Done, Running')
	,(5,'Process_GenerateMsgNoti', 'Done', 'String', 'Done, Running')
	,(6,'Process_PushNoti', 'Done', 'String', 'Done, Running')
	
	,(7,'ProcessUAT_CaptureData', 'Done', 'String', 'Done, Running')
	,(8,'ProcessUAT_GenerateMsgNoti', 'Done', 'String', 'Done, Running')
	,(9,'Process_GenerateLapNoti', 'Done', 'String', 'Done, Running')
	
	,(10,'UATMode', '0', 'Boolean', 'Turn ON/OFF UATMode; If UATMode = OFF, PRD handle all data; If UATMode = ON, 1.PRD handle REAL data only 2.UAT handle REAL TEST (test matches)')
	,(11,'Retrieving_WaitSec', '30', 'Int32', 'Change Status [Retrieving] -> [Successfully Retrieved] IF the SessionID keep Retrieving over this configuration')
	,(12,'IT ChatGroupID', NULL, 'String','IT ChatGroupID')
	,(13,'LogMode', 'Debug', 'String', 'Normal, Debug')
	,(14,'OST ChatGroupID', '19:934a887696734ecfbc35dc45521729c4@thread.skype', 'String','Notification Alert - Local')
	,(15,'777 ChatGroupID', '19:85743ff1eb01435d899cbc1a4f756f47@thread.skype', 'String','Notification Alert (for 777 only) - Local')
	,(16,'Separate Noti by Site', '777777', 'String','Sites will be separated notifications from OST')

/***** NotiTemplate ****/
TRUNCATE TABLE NotiTemplate

DECLARE @StarixIT INT
SELECT @StarixIT = TRY_CONVERT(INT, VValue)
FROM SystemSetting WITH (NOLOCK)
WHERE VID = 2 --ID of StarixIT

INSERT INTO NotiTemplate (
	TemplateID
	,TemplateName
	,Content_en
	,Content_ch
	,Content_cs
	,RequiredParams
	,CreatorID
	,LastModifiedBy
	,Remark
)
VALUES (
		1
		,'Result Amendment for Cricket - Calculate to Refund or Refund to Calculate (1 or 2 amended results)'
		,N'Attn:[{sport_name}] Due to {affected_result_name} wrong calculation, all bets place on {match_info} as a result bet ID: "@@" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於 {affected_result_name} 成績結算有誤, 所有注單投注於 {match_info} 注單: "@@" 已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒!'
		,N'请注意:[{sport_name}] 由于 {affected_result_name} 成绩结算有误, 所有注单投注于 {match_info} 注單: "@@" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{affected_result_name},{match_info}'
		,@StarixIT
		,@StarixIT
		,'CAL to Refund or Refund to CAL (Wrong Calculation) - Amended Result is 1 or 2'
	)
	,(
		2
		,'Result Amendment for Cricket - Calculate to Refund or Refund to Calculate (Over 2 amended results)'
		,N'Attn:[{sport_name}] Due to wrong calculation, all bets place on {match_info} has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於成績結算有誤, 所有注單投注於 {match_info} 注單: "@@"已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒!'		
		,N'请注意:[{sport_name}] 由于成绩结算有误, 所有注单投注于 {match_info} 注單: "@@" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{match_info}'
		,@StarixIT
		,@StarixIT
		,'CAL to Refund or Refund to CAL (Wrong Calculation) - Amended Result is more than 2'
	)
	,(
		3
		,'Result Amendment for Cricket - Calculate to Calculate (1 amended result)'
		,N'Attn:[{sport_name}] Due to {affected_result_name} wrong result displayed, the match between {match_info} as a result bet ID: "@@" has been re-settled. The actual result is "{new_value}" instead of "{old_value}". Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於 {affected_result_name} 賽果顯示錯誤, {match_info} 注單: "@@" 已重新結算. 正確之賽果為 "{new_value}" 而不是 "{old_value}". 請重新檢查您的帳目. 不便之處 敬請見諒!'
		,N'请注意:[{sport_name}] 由于 {affected_result_name} 赛果显示错误, {match_info} 注單: "@@" 已重新结算. 正确之赛果为 "{new_value}" 而不是 "{old_value}". 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{affected_result_name},{match_info},{new_value},{old_value}'
		,@StarixIT
		,@StarixIT
		,'CAL to CAL (Wrong Result) - Amended Result is 1'
	)
	,(
		4
		,'Result Amendment for Cricket - Calculate to Calculate (2 amended results)'
		,N'Attn:[{sport_name}] Due to {affected_result_name} wrong result displayed, the match between {match_info} as a result bet ID: "@@" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於 {affected_result_name} 賽果顯示錯誤, {match_info} 注單: "@@" 已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒! '
		,N'请注意:[{sport_name}] 由于 {affected_result_name} 赛果显示错误, {match_info} 注單: "@@" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{affected_result_name},{match_info}'
		,@StarixIT
		,@StarixIT
		,'CAL to CAL (Wrong Result) - Amended Result is 1'
	)
	,(
		5
		,'Result Amendment for Cricket - Calculate to Calculate (Over 2 amended results)'
		,N'Attn:[{sport_name}] Due to wrong result displayed, the match between {match_info} as a result bet ID: "@@" has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
		,N'請注意:[{sport_name}] 由於賽果顯示錯誤, {match_info} 注單: "@@" 已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒!'
		,N'请注意:[{sport_name}] 由于赛果显示错误, {match_info} 注單: "@@" 已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
		,N'{sport_name},{match_info}'
		,@StarixIT
		,@StarixIT
		,'CAL to CAL (Wrong Result) - Amended Result is more than 2'
	)
	,(
		6
		,'Result Amendment for Cricket'
		,N'<b>Dear Valued Customers,</b><br/><br/>Please be informed that the match between "{match_name}" [{league_name} - {event_date}], result has been amended. Please refer to below for more information:<br/><br/><b>English Message:-</b><br/>{notification}<br/><br/><b>Settlement log:<br/>(System Time)</b><br/>{cal_time}<br/>{recal_time}<br/><br/><b style="color:red">Kindly refer to the attached file for those affected customers & tickets.</b><br/><br/>Sorry for the inconvenience caused and thank you for your kind attention!<br/><br/><b>Best Regards,</b><br/>(CS input name here for the one who check)<br/><b>Customer Service Team</b>'
		,NULL
		,N'<b>亲爱的客户，</b><br/><br/>请注意, 赛事 "{match_name}" [{league_name} - {event_date}], 赛果已重新结算。有关详情，请参考以下资讯：<br/><br/><b>中文信息:-</b><br/>{notification}<br/><br/><b>结算日志:<br/>(系统时间)</b><br/>{cal_time}<br/>{recal_time}<br/><br/><b style="color:red">有关受影响的会员和注单请参阅附件。</b><br/><br/>不便之处, 敬请见谅。谢谢!<br/>'
		,N'{match_name},{league_name},{event_date},{notification},{cal_time},{recal_time}'
		,@StarixIT
		,@StarixIT
		,'Result Amendment for Cricket - Notification for LAP with HTML format - {cal_time} can be multi rows'
	)

/***** AlertRule ****/
TRUNCATE TABLE AlertRule
INSERT INTO AlertRule (
	RuleID
	,RuleName
	,RuleType
	,SQLStatement
	,ChatGroupIDs
	-- ,LastScan
)
VALUES (
		1
		,'SysErr - Running Status Too Long'
		,'SysErr'
		,''
		,'12,14,15'
	)
	,(
		2
		,'NewNoti - Need Review'
		,'NewNoti'
		,''
		,'14,15'
	)
	,(
		3
		,'PushErr - Sent Issue'
		,'PushErr'
		,''
		,'12,14,15'
	)
	,(
		4
		,'SysErr - Missing From Any SiteGroupDB'
		,'SysErr'
		,''
		,'12,14,15'
	)