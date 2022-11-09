/*<info serverAlias="DBCRM-bodb_CRM" executers="" ></info>*/
/*
	Created: 20221110@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Delete log

*/

DECLARE @Table TABLE (ID INT IDENTITY(1, 1), DataSource NVARCHAR(128)) 
INSERT INTO @Table (DataSource)
VALUES ('DBCust.CustDB.dbo.CustCategoryHistory')
	,('DB052.bodb02.dbo.TicketAmendment_Detail')
	,('DB053.bodb02.dbo.TicketAmendment_Detail')
	,('DBMSG.bodb_Message.dbo.Msg')

DECLARE @ID INT = 1, @DataSource NVARCHAR(128), @NotificationId INT = 151046	

WHILE EXISTS (SELECT 1 FROM @Table t WHERE t.ID = @ID)
BEGIN
	SELECT @DataSource = DataSource FROM @Table WHERE ID = @ID

	WHILE 1 = 1
	BEGIN
		DELETE TOP(3000) dbo.crmNotificationReference WITH(ROWLOCK, UPDLOCK)
		WHERE DataSource = @DataSource AND NotificationId <= @NotificationId

		IF @@ROWCOUNT = 0
			BREAK
	END

	SET @ID += 1
END





