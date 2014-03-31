
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.WriteLog_UserLog_crmLogCustomer    Script Date: 3/26/2014 6:06:10 PM ******/

CREATE PROCEDURE [dbo].[WriteLog_UserLog_crmLogCustomer]
(
	@CustID		INT, 
	@UserID		VARCHAR(50), 
	@ActionID	INT, 
	@IP			VARCHAR(15),	
	@NewValues	xml,
	@OldValues	xml = NULL
)
AS
/*
Created: Lukas
Date: 20101103
Task : write crmLogCutomer
DB: DB06.bodb_CRM
Original:

Revisions:
	- 20140303@Dom: Modify for new structure
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
					Doing,
					OldValues
				)
			VALUES
				(
					getdate(), 
					@CustID, 
					@UserID, 
					@ActionID, 
					@IP, 
					@NewValues,
					@OldValues
				)
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[WriteLog_UserLog_crmLogCustomer] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[WriteLog_UserLog_crmLogCustomer] TO [vnteam]
GO 
