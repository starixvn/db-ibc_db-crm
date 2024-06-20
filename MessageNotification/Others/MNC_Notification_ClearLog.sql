/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_ClearLog
AS
/*
	Created: 20231213@Roy
	Task: Clear Log
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_ClearLog
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @KeepTime DATETIME = DATEADD(DD, - 30, GETDATE())
	
	WHILE (1 = 1)
	BEGIN
		DELETE TOP (3000) dbo.UserLog
		WHERE LogTime < @KeepTime

		IF @@ROWCOUNT = 0
			BREAK
	END
END
