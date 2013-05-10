


alter PROCEDURE [dbo].[Acc_CRM_CustomerUpdUsername]
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

	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET username = @NewUsername
	WHERE custid = @custid
	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 101,
				@ErrMsg = 'crmCustomer: Update username unsuccessfully.'
		RETURN
	END

	UPDATE crmCustsearch WITH(ROWLOCK,UPDLOCK)
	SET username = @NewUsername
	WHERE custid = @custid
	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 100,
				@ErrMsg = 'crmCustsearch: Update username unsuccessfully.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML
	SELECT @LogElement =
					'<Acc_CRM_CustomerUpdUsername>' + --SP Name
						'<NewUsername>'		+ ISNULL(@NewUsername,'')			+ '</NewUsername>' +											
					'</Acc_CRM_CustomerUpdUsername>'
	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 104, 
					@IP = @IP, 
					@Doing = @LogElement
END
GO
GRANT VIEW DEFINITION ON Acc_CRM_CustomerUpdUsername TO vnteam
GO
GRANT EXECUTE ON Acc_CRM_CustomerUpdUsername TO bodbAdminNet

