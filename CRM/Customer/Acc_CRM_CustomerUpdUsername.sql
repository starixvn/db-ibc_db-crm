/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap,vnteam" viewers="wsv_nap,vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerUpdUsername]
(
	@NewUsername VARCHAR(30),
	@CustID		INT,	
	@UserID		INT = 8,
	@IP			VARCHAR(15) = '',
	@ErrCode	INT				= 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
	Created: Lukas
	Date: 20120704
	Task : call from DBTRANS when admin update username
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20140303@Dom: Modify for new structure
		- 20241010@Helen:edit username for CREDIT - [Redmine:#212007]

	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''
			
	IF EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE UserName = @NewUsername AND CustID > 0)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Username already existed.'
		--> go to rollback customer/custinfo and Mini table called by WEB

		RETURN
	END

	DECLARE @Username_Old VARCHAR(30)
	 
	SELECT @Username_Old = UserName
	FROM crmCustomer WITH(NOLOCK) 
	WHERE CustID = @CustID

	IF @@ROWCOUNT = 0
		RETURN

	BEGIN TRY

		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
			SET username = @NewUsername
		WHERE custid = @custid

		UPDATE crmCustomerSearch WITH(ROWLOCK,UPDLOCK)
			SET username = @NewUsername
		WHERE custid = @custid

		
	END TRY
	BEGIN CATCH

		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
			SET username = @Username_Old
		WHERE custid = @custid

		UPDATE crmCustomerSearch WITH(ROWLOCK,UPDLOCK)
			SET username = @Username_Old
		WHERE custid = @custid

		SELECT @ErrMsg = 'Update crm username does not successfully. ' + @ErrMsg
			, @ErrCode = 100
		--> go to rollback customer/custinfo and Mini table called by WEB
		RETURN

	END CATCH

	-- write log
	DECLARE @OldValues XML,@NewValues XML

	SELECT @OldValues =
					'<Acc_CRM_CustomerUpdUsername>' + --SP Name
						'<NewUsername>'		+ ISNULL(@Username_Old,'')			+ '</NewUsername>' +											
					'</Acc_CRM_CustomerUpdUsername>'
	SELECT @NewValues =
					'<Acc_CRM_CustomerUpdUsername>' + --SP Name
						'<NewUsername>'		+ ISNULL(@NewUsername,'')			+ '</NewUsername>' +											
					'</Acc_CRM_CustomerUpdUsername>'

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 104, 
					@IP = @IP, 
					@NewValues = @NewValues,
					@OldValues = @OldValues
END
GO 
