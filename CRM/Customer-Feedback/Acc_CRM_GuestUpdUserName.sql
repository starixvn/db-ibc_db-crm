ALTER PROCEDURE [dbo].[Acc_CRM_GuestUpdUserName]
(
	@UserID		INT,
	@CustID		INT,
	@UserName	NVARCHAR(50),
	@IP			VARCHAR(15),
	@ErrCode	INT				= 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
	Created: Lukas
	Date: 20101123
	Task : update customer info
	DB: DB06.bodb_CRM
	Original:

	Revisions:
		- 20110701@Lukas: support update username for guest
		- 20120503@Elodie: check if user exists in CRM system before updating
	Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''
	IF EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE UserName = @UserName AND CustID < 0)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Username already existed.'
		RETURN
	END
	-- update guets's username
	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET Username = @Username
	WHERE CustID = @CustID

	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 100,
				@ErrMsg = 'Update username unsuccessfully.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement =
					'<Acc_CRM_GuestUpdUserName>' + --SP Name
						'<UserName>'		+ ISNULL(@UserName,'')	+ '</UserName>' +						
					'</Acc_CRM_GuestUpdUserName>'
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 103, 
					@IP = @IP, 
					@Doing = @LogElement
	
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_GuestUpdUserName] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_GuestUpdUserName] TO [vnteam]