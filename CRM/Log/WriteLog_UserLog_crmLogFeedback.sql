ALTER PROCEDURE [dbo].[WriteLog_UserLog_crmLogFeedback]
(
	@UserID			INT, 
	@FeedbackID		INT,
	@CustID			INT,
	@ActionID		INT, 
	@IP				VARCHAR(15),	
	@Description	NVARCHAR(MAX),
	@Solution		NVARCHAR(MAX),
	@Review			NVARCHAR(MAX),
	@NewValues		XML,
	@OldValues		XML = NULL
)
AS
/*
Created: Lukas
Date: 20101103
Task : write crmLogFeedback
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

	INSERT INTO crmLogFeedback
				(
					LogDate, 
					FeedbackID,
					CustID, 
					UserID, 
					ActionID, 
					IP, 
					Description, 
					Solution, 
					Review, 
					Doing,
					OldValues
				)
			VALUES
				(
					getdate(), 
					@FeedbackID, 
					@CustID, 
					@UserID, 
					@ActionID, 
					@IP, 
					@Description, 
					@Solution, 
					@Review,
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
 GRANT EXECUTE ON [dbo].[WriteLog_UserLog_crmLogFeedback] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[WriteLog_UserLog_crmLogFeedback] TO [vnteam]
GO 
