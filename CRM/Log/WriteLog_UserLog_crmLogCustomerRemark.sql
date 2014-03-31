
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.WriteLog_UserLog_crmLogCustomerRemark    Script Date: 3/26/2014 6:06:10 PM ******/
CREATE PROCEDURE WriteLog_UserLog_crmLogCustomerRemark
	@CustID int,
	@UserID int,
	@ActionID int,
	@IP varchar(15),
	@NewValues xml,
	@OldValues xml = NULL
AS

/*
	Created: Dom
	Date: 20140217
	Task : Write Log Customer Remark
	DB: DBCRM.bodb_CRM
	Original:

	Revisions:
	Param's Explanation:
	
*/

INSERT INTO [crmLogCustomerRemark]
           ([LogDate]
           ,[CustID]
           ,[UserID]
           ,[ActionID]
           ,[IP]
           ,[NewValues]
           ,[OldValues])
     VALUES
			(GETDATE(),
           @CustID,
           @UserID,
           @ActionID,
           @IP,
           @NewValues,
           @OldValues)

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
