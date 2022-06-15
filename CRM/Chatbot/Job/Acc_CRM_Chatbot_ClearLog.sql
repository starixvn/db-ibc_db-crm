/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE dbo.Acc_CRM_Chatbot_ClearLog
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @Date DATETIME = CONVERT(DATE, DATEADD(MONTH, -1, GETDATE()))

	WHILE 1 = 1
	BEGIN
		DELETE TOP(2000) r WITH(ROWLOCK, UPDLOCK)
		FROM dbo.crmNotificationReference r
		WHERE r.CreatedDate <= @Date

		IF @@ROWCOUNT = 0
			BREAK
	END
END