/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
	@OldValues		XML = NULL,
	@Duration		INT = NULL
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
	- 20200604@Johnson: add Duration for tracking fb [redmine:#135337]
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
					OldValues,
					Duration
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
					@OldValues,
					@Duration
				)
END



GO

