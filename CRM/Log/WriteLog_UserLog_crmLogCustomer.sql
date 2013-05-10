
ALTER PROCEDURE [dbo].[WriteLog_UserLog_crmLogCustomer]
(
	@CustID		INT, 
	@UserID		VARCHAR(50), 
	@ActionID	INT, 
	@IP			VARCHAR(15),	
	@Doing		XML
)
AS
/*
Created: Lukas
Date: 20101103
Task : write crmLogCutomer
DB: DB06.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
	- @UserID: UserId perform this action
	- @CustID: 
	- @ActionID: Log action Id
	- @Doing: xml string format
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO crmLogCustomer
				(
					LogDate, 
					CustID, 
					UserID, 
					ActionID,  
					IP, 
					Doing
				)
			VALUES
				(
					getdate(), 
					@CustID, 
					@UserID, 
					@ActionID, 
					@IP, 
					@Doing
				)
END



GO
GRANT EXECUTE ON [dbo].[WriteLog_UserLog_crmLogCustomer] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[WriteLog_UserLog_crmLogCustomer] TO [vnteam]