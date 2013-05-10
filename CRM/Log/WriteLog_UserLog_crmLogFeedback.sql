
ALTER PROCEDURE [dbo].[WriteLog_UserLog_crmLogFeedback]
(
	@UserID			INT, 
	@FeedbackID		INT,
	@CustID			INT,
	@ActionID		INT, 
	@IP				VARCHAR(15),	
	@Description	NVARCHAR(MAX),
	@Solution		NVARCHAR(MAX),
	@Review			NVARCHAR(4000),
	@Doing			XML
)
AS
/*
Created: Lukas
Date: 20101103
Task : write crmLogFeedback
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
					Doing
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
					@Doing
				)
END


GO
GRANT EXECUTE ON [dbo].[WriteLog_UserLog_crmLogFeedback] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[WriteLog_UserLog_crmLogFeedback] TO [vnteam]