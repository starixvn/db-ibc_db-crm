/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_crmUserLog_RunSP]
(
	@UserID			INT, 
	@CustId     	INT,
	@ActionID		INT, 
	@IP				VARCHAR(20),	
	@NewValues		NVARCHAR(MAX) ='',
	@OldValues		NVARCHAR(MAX) =''
)
AS
/*
Created: 20200506@Malcolm
Task :  write log to crmUserLog_RunSP table
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: write log to crmUserLog_RunSP table [RedmineId: #108739]
		- 20200722@Malcolm: Add CustId [RedmineId : #137144]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO crmUserLog_RunSP
				(
					LogDate, 
					UserID, 
					CustID,
					ActionID,  
					IP, 
					NewValues,
					OldValues
				)
			VALUES
				(
					DATEADD(HOUR,8,GETUTCDATE()), 
					@UserID, 
					@CustId,
					@ActionID, 
					@IP, 
					@NewValues,
					@OldValues
				)
END
GO