/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
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
		- 20140303@Dom: Modify for new structure
		- 20171204@Winnie: HotFix Record special characters included in feedback content RedmineID: RedmineID: #85858
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

	DECLARE @Username_Old NVARCHAR(50)
	SELECT @Username_Old = Username
	FROM crmCustomer WITH(NOLOCK)
	WHERE CustID = @CustID

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

	UPDATE crmCustomerSearch WITH(ROWLOCK,UPDLOCK)
	SET Username = @Username
	WHERE CustID = @CustID

	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 100,
				@ErrMsg = 'Update username unsuccessfully.'
		RETURN
	END

	-- write log
	DECLARE @NewValues XML,@OldValues XML

	SELECT @NewValues =
					'<Acc_CRM_GuestUpdUserName>' + --SP Name
						'<UserName>'		+ ISNULL([dbo].[f_EncodeXMLValue](@UserName),'')		+ '</UserName>' +						
					'</Acc_CRM_GuestUpdUserName>'

	SELECT @OldValues =
					'<Acc_CRM_GuestUpdUserName>' + --SP Name
						'<UserName>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Username_Old),'')		+ '</UserName>' +						
					'</Acc_CRM_GuestUpdUserName>'
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 103, 
					@IP = @IP, 
					@NewValues = @NewValues,
					@OldValues = @OldValues
	
END


GO
