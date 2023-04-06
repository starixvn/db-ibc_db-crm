/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_IgnoredNotificationType_Sel]
AS
/*
	Created: 20221222@Malcolm
	Task :  Get Ignored notification types
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221222@Malcolm: Initialize SPs [Redmine: #130544]
		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ServiceNotificationType TABLE (ServiceName VARCHAR(100), NotificationTypeId SMALLINT)

	;WITH CTE_Service AS
	(
		SELECT ServiceName
		FROM (
			VALUES 
			('ChatBot - AbnormalBets')
			,('ChatBot - TOControl')
			,('ChatBot - CWL')
			,('ChatBot - ProblemAccounts')
			,('ChatBot - ResultAmendment')
			,('ChatBot - ArchivedAccounts')
		) AS s (ServiceName)
	)
	INSERT INTO @ServiceNotificationType (ServiceName, NotificationTypeId)
	SELECT DISTINCT s.ServiceName, r.NotificationTypeId
	FROM CTE_Service s
		INNER JOIN dbo.SystemSetting st WITH(NOLOCK) ON st.ServiceName = s.ServiceName AND st.SettingName = 'NotificationTemplate'
		CROSS APPLY (SELECT CONVERT(XML, st.Value) AS NotificationTemplateXML) n
		CROSS APPLY (
			SELECT t.c.value('@NotificationTypeID', 'SMALLINT') AS NotificationTypeId
			FROM n.NotificationTemplateXML.nodes('root/r') t(c)
		) AS r (NotificationTypeId)

	SELECT nt.NotificationTypeId, nt.NotificationTypeName
	FROM dbo.crmNotificationType nt WITH(NOLOCK)
	WHERE NOT EXISTS (
		SELECT 1 FROM @ServiceNotificationType sn WHERE sn.NotificationTypeId = nt.NotificationTypeId
	)

END
GO
