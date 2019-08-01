/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROC Acc_CRM_CustomerInformationVerify
	@CustID					INT,
	@IsVerifyEmail			BIT = 0,
	@IsVerifyPassport		BIT = 0,
	@IsVerifyBirthday		BIT = 0,
	@IsVerifySecretCode		BIT = 0,
	@IsVerifyBetCredit		BIT = 0,
	@IsVerifyGivenCredit	BIT = 0,
	@UserID					INT,
	@IP						VARCHAR(15),
	@ErrCode				INT				= 0 OUTPUT,
	@ErrMsg					NVARCHAR(4000)	= '' OUTPUT
AS

/*
Created: Dom
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20190711@Winnie: CRM - Enhance Inform Headline RedmineID:##109775
Param's Explanation:	
*/

	IF NOT EXISTS(SELECT 1 FROM crmCustomer(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		EXEC Acc_CRM_CopyCustomerInformation
			@CustID		= @CustID,
			@UserID		= @UserID,
			@IP			= @IP,
			@ErrCode	= @ErrCode OUTPUT,
			@ErrMsg		= @ErrMsg OUTPUT

			IF @ErrCode <> 0
				RETURN
	END

	DECLARE @IsVerifyEmail_Old			BIT = 0,
			@IsVerifyPassport_Old		BIT = 0,
			@IsVerifyBirthday_Old		BIT = 0,
			@IsVerifySecretCode_Old		BIT = 0,
			@IsVerifyBetCredit_Old		BIT = 0,
			@IsVerifyGivenCredit_Old	BIT = 0

	SELECT @IsVerifyEmail_Old		= IsVerifyEmail,
		@IsVerifyPassport_Old		= IsVerifyPassport,
		@IsVerifyBirthday_Old		= IsVerifyBirthday,
		@IsVerifySecretCode_Old		= IsVerifySecretCode,
		@IsVerifyBetCredit_Old		= IsVerifyBetCredit,
		@IsVerifyGivenCredit_Old	= IsVerifyGivenCredit
	FROM crmCustomer WITH(NOLOCK)
	WHERE CustID = @CustID

	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET IsVerifyEmail		= @IsVerifyEmail,
		IsVerifyPassport	= @IsVerifyPassport,
		IsVerifyBirthday	= @IsVerifyBirthday,
		IsVerifySecretCode	= @IsVerifySecretCode,
		IsVerifyBetCredit	= @IsVerifyBetCredit,
		IsVerifyGivenCredit = @IsVerifyGivenCredit
	WHERE CustID = @CustID
	
	IF @@error <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'Cannot update customer.'
		RETURN
	END

	-- write log
	DECLARE @NewValues XML,@OldValues XML

	SELECT @OldValues = 				
					'<Acc_CRM_CustomerInformationVerify>'			+ --SP Name
						'<IsVerifyEmail>'					+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyEmail_Old),'')			+ '</IsVerifyEmail>' +
						'<IsVerifyPassport>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyPassport_Old),'')			+ '</IsVerifyPassport>' +
						'<IsVerifyBirthday>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyBirthday_Old),'')			+ '</IsVerifyBirthday>' +
						'<IsVerifySecretCode>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifySecretCode_Old),'')			+ '</IsVerifySecretCode>' +
						'<IsVerifyBetCredit>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyBetCredit_Old),'')			+ '</IsVerifyBetCredit>' +
						'<IsVerifyGivenCredit>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyGivenCredit_Old),'')			+ '</IsVerifyGivenCredit>' +
					'</Acc_CRM_CustomerInformationVerify>' 
	
	SELECT @NewValues = 				
					'<Acc_CRM_CustomerInformationVerify>'			+ --SP Name
						'<IsVerifyEmail>'					+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyEmail),'')			+ '</IsVerifyEmail>' +
						'<IsVerifyPassport>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyPassport),'')			+ '</IsVerifyPassport>' +
						'<IsVerifyBirthday>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyBirthday),'')			+ '</IsVerifyBirthday>' +
						'<IsVerifySecretCode>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifySecretCode),'')			+ '</IsVerifySecretCode>' +
						'<IsVerifyBetCredit>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyBetCredit),'')			+ '</IsVerifyBetCredit>' +
						'<IsVerifyGivenCredit>'				+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyGivenCredit),'')			+ '</IsVerifyGivenCredit>' +
					'</Acc_CRM_CustomerInformationVerify>' 

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
				@CustID = @CustID, 
				@UserID = @UserID, 
				@ActionID = 102, 
				@IP = @IP, 
				@NewValues = @NewValues,
				@OldValues = @OldValues


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerInformationVerify] TO [bodbAdminNet]
GO 
