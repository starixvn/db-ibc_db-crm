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
		RETURN
	END

	 DECLARE @Username_Old VARCHAR(30)
	 SELECT @Username_Old = UserName
	 FROM crmCustomer WITH(NOLOCK) 
	 WHERE CustID = @CustID

	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET username = @NewUsername
	WHERE custid = @custid
	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 101,
				@ErrMsg = 'crmCustomer: Update username unsuccessfully.'
		RETURN
	END

	UPDATE crmCustomerSearch WITH(ROWLOCK,UPDLOCK)
	SET username = @NewUsername
	WHERE custid = @custid
	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 100,
				@ErrMsg = 'crmCustsearch: Update username unsuccessfully.'
		RETURN
	END

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

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerUpdUsername] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerUpdUsername] TO [vnteam]
GO 
