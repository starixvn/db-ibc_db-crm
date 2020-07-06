/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_crmUserLog_RunSP]
(
	@UserID		VARCHAR(50), 
	@ActionID	INT, 
	@IP			VARCHAR(15),	
	@NewValues	xml,
	@OldValues	xml = NULL
)
AS
/*
Created: 20200506@Malcolm
Task :  write log to crmUserLog_RunSP table
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: write log to crmUserLog_RunSP table [Redmine: #108739]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO crmUserLog_RunSP
				(
					LogDate, 
					UserID, 
					ActionID,  
					IP, 
					NewValues,
					OldValues
				)
			VALUES
				(
					getdate(), 
					@UserID, 
					@ActionID, 
					@IP, 
					@NewValues,
					@OldValues
				)
END
GO