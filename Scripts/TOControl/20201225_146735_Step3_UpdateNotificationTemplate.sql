/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201225@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert notification template [RedmineId : #146735]
*/
--Step 3
--Insert notification template
DECLARE @NotificationTemplateId INT

SELECT @NotificationTemplateId = NotificationTemplateId FROM dbo.crmNotificationTemplate WITH(NOLOCK) WHERE NotificationTemplateName = 'Turnover Control Template'

DECLARE @Content TABLE (LanguageId INT, Content NVARCHAR(MAX))

INSERT @Content (LanguageId, Content)
VALUES (50000, N'Dear Sir, Customer Support would like to inform that members under {SMA_level_en} "{SMA_username}" has the possibility to 
lose with the below info:

Outstanding: {event_outstanding} ({currency_name})
Sport: {sport_name_en}
League: {league_name_en}
Team: {home_name_en} -vs- {away_name_en}

Kindly take note, thank you!')
, (50001, N'您好，客服部在此通知您 {SMA_level_sc} "{SMA_username}" 旗下会员有可能会输总计 未结束交易 如下：

未结束交易额: {event_outstanding} ({currency_name})
产品：{sport_name_sc}
联赛：{league_name_sc}
队名：{home_name_sc} -vs- {away_name_sc}

请您留意 谢谢！')
,(50002,N'Dear Sir, Customer Support would like to inform that members under {SMA_level_en} "{SMA_username}" has the possibility to 
lose with the below info:

Outstanding: {event_outstanding} ({currency_name})
Sport: {sport_name_en}
League: {league_name_en}
Team: {home_name_en} -vs- {away_name_en}

Kindly take note, thank you!"

您好，客服部在此通知您 {SMA_level_sc} "{SMA_username}" 旗下会员有可能会输总计 未结束交易 如下：

未结束交易额: {event_outstanding} ({currency_name})
产品：{sport_name_sc}
联赛：{league_name_sc}
队名：{home_name_sc} -vs- {away_name_sc}

请您留意 谢谢！')
,(50003, N'เรียน ลูกค้าที่เคารพ ฝ่ายบริการลูกค้าขอแจ้งให้ทราบว่าสมาชิภายใต้ {SMA_level_th} "{SMA_username}" อาจจะมีการเสียยอดคงค้างตามรายละเอียดด้านล่าง:

ยอดคงค้าง:  {event_outstanding} ({currency_name})
โปรดักส์:  {sport_name_th}
ลีก: {league_name_th}
ชื่อทีม: {home_name_th} -vs- {away_name_th}

จึงเรียนมาเพื่อทราบ ขอบคุณค่ะ')
,(50004, N'Kính chào Quý Khách, Bộ phận chăm sóc Khách Hàng xin thông báo tới Quý Khách các thành viên thuộc {SMA_level_en} "{SMA_username}" có khả năng thua như sau:

Số dư chưa xử lý: {event_outstanding} ({currency_name})
Môn thể thao: {sport_name_yn}
Giải đấu: {league_name_yn}
Trận đấu: {home_name_yn} -vs- {away_name_yn}

Xin vui lòng lưu ý, cám ơn Quý Khách!')

INSERT dbo.crmNotificationTemplateContent(NotificationTemplateId, LanguageId, Content)
SELECT @NotificationTemplateId, LanguageId, Content
FROM @Content