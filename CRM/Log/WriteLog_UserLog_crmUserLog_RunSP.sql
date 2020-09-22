/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_crmUserLog_RunSP]
(
	@UserID			INT, 
	@CustId     	INT,
	@CustIds		VARCHAR(1000) = '',
	@ReferenceIds	VARCHAR(1000) = '',
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

	INSERT INTO dbo.crmUserLog_RunSP
				(
					LogDate, 
					UserID, 
					CustID,
					CustIds,
					ReferenceIds,
					ActionID,  
					IP, 
					NewValues,
					OldValues
				)
			VALUES
				(
					GETDATE(), 
					@UserID, 
					@CustId,
					@CustIds,
					@ReferenceIds,
					@ActionID, 
					@IP, 
					@NewValues,
					@OldValues
				)
END
GO