/*<info serverAlias="DBCRM-MessageNotification"></info>*/
/*
	Created: 20250417@Dave
	Task: Init data - [NotiTemplateMapping] [Redmine: #227143]
	DB: DBCRM.MessageNotification
*/
USE [MessageNotification]
GO

DECLARE @StarixIT INT
SELECT @StarixIT = TRY_CONVERT(INT, VValue)
FROM SystemSetting WITH (NOLOCK)
WHERE VID = 2; --ID of StarixIT

DELETE FROM NotiTemplate WHERE TemplateID = 11;

INSERT INTO NotiTemplate (
	TemplateID
	,TemplateName
	,Content_en
	,Content_ch
	,Content_cs
	,Content_zhcn
	,RequiredParams
	,CreatorID
	,LastModifiedBy
	,Remark
)
VALUES (
	11
	,'Result Amendment for {sport_name}'
	,N'Attn:[{sport_name}] Due to wrong result displayed, {match_info}, bet ID: "@@" placed has been re-settled. Kindly double check your statement again. Sorry for the inconvenience caused!'
	,N'請注意:[{sport_name}] 由於賽果顯示錯誤, {match_info}, 注單: "@@" 投注已重新結算. 請重新檢查您的帳目. 不便之處 敬請見諒!'
	,N'请注意:[{sport_name}] 由于赛果显示错误, {match_info}, 注单: "@@" 投注已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
	,N'请注意:[{sport_name}] 由于赛果显示错误, {match_info}, 注单: "@@" 投注已重新结算. 请重新检查您的帐目. 不便之处 敬请见谅!'
	,N'{sport_name},{match_info}'
	,@StarixIT
	,@StarixIT
	,'CAL to CAL (Wrong Result) - Amended Result is more than 2'
);

DELETE FROM NotiTemplateMapping_UAT WHERE SportType = 1;

/*NotiTemplateMapping*/
INSERT INTO NotiTemplateMapping_UAT ([TemplateID], [SportType], [NotificationType], [ActionType], [MinAmended], [MaxAmended])
VALUES(11, 1, 1, 5, 1, 99);

INSERT INTO NotiTemplateMapping_UAT ([TemplateID], [SportType], [NotificationType], [ActionType], [MinAmended], [MaxAmended])
VALUES(6, 1, 2, NULL, NULL, NULL);

SELECT * FROM NotiTemplate WITH(NOLOCK) WHERE TemplateID = 11;
SELECT * FROM NotiTemplateMapping_UAT WITH(NOLOCK) WHERE SportType = 1;