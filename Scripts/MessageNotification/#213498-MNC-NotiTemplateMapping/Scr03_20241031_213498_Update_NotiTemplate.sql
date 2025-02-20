/*<info serverAlias="DBCRM-MessageNotification"></info>*/
/*
	Created: 20241031@Tacy
	Task: Init data - new table [NotiTemplateMapping] [Redmine: #213498]
	DB: DBCRM.MessageNotification
*/

USE MessageNotification
GO

-- NotiTemplate: update [TemplateName]
UPDATE NotiTemplate WITH (ROWLOCK, UPDLOCK)
SET TemplateName = CASE WHEN TemplateID = 4 THEN 'Result Amendment for {sport_name} - Calculate to Calculate (2 or over 2 amended results)'
						ELSE REPLACE(TemplateName, 'Cricket', '{sport_name}')
					END
	, RequiredParams = CASE WHEN TemplateID=6 THEN '{sport_name},' + RequiredParams ELSE RequiredParams END
WHERE TemplateID<=6
GO

-- NotiTemplate: update [Remark]
UPDATE NotiTemplate WITH (ROWLOCK, UPDLOCK)
SET Remark = CASE WHEN  TemplateID=4 THEN 'CAL to CAL (Wrong Result) - Amended Result is 2 or more than 2'
				ELSE REPLACE(Remark, 'Result Amendment for Cricket', 'Result Amendment') 
			END
WHERE TemplateID BETWEEN 4 AND 10
GO