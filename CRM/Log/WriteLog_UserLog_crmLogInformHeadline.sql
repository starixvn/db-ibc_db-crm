ALTER PROCEDURE [dbo].[WriteLog_UserLog_crmLogInformHeadline]
(
	@CustID		INT = 0, 
	@TitleID	INT,
	@UserID		INT, 
	@ActionID	INT, 
	@IP			VARCHAR(15),	
	@NewValues	xml,
	@OldValues	xml = NULL
)
AS
/*
	Created: Elodie
	Date: 20150406
	Task : write crmLogInformHeadline_New
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
	
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	INSERT INTO crmLogInformHeadline_New (LogDate, UserID, ActionId, IP, CustID, TitleID, NewValues, OldValues)
	VALUES (GETDATE(), @UserID, @ActionID, @IP, @CustID, @TitleID, @NewValues, @OldValues)
END
