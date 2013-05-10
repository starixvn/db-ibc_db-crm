ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackInfoUpd]
(
	@UserID				INT,
	@FeedbackID			INT,
	@CustID				INT,
	@TitleID			INT,
	@FirstName			NVARCHAR(50),
	@LastName			NVARCHAR(50),
	@Phone				NVARCHAR(50),
	@MobilePhone		NVARCHAR(50),
	@Fax				NVARCHAR(50),
	@Email				NVARCHAR(254),
	@Skype				NVARCHAR(100),
	@MSN				NVARCHAR(100),
	@LanguageID			INT,
	@CountryID			INT,
	@Subject			NVARCHAR(200)	= NULL,
	@RelatedCustID		NVARCHAR(500)	= NULL,
	@FeedbackDate		DATETIME,	
	@ResolutionDate		DATETIME,
	@CommunicationID	INT,
	@StationID			INT,
	@MainCategoryID		INT,
	@SubCategoryID		INT,
	@SiteID				INT,
	@RoleID				INT,
	@ProductID			INT,
	@BettypeID			INT,
	@ResponseID			INT,
	@StatusID			INT,
	@Description		NVARCHAR(MAX),
	@Solution			NVARCHAR(MAX),
	@UpdateReviewedMode	TINYINT = 0,
	@IsReviewed			BIT				= 0,
	@Review				NVARCHAR(4000),
	@ReviewerID			INT				= NULL,
	@IP					VARCHAR(15),
	@Pic1				NVARCHAR(100)	= NULL,
	@Pic2				NVARCHAR(100)	= NULL,
	@Pic3				NVARCHAR(100)	= NULL,
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT,
	@IsOverWrite		BIT				= 0	
)
AS
/*
	Created: Lukas
	Date: 20101023
	Task : update feedback info
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas: support multiple feedback related customer
		- 20120307@Elodie: add 3 params @Pic1, @Pic3, @Pic3
		- 20120319@Elodie: change DB06 to DB052
		- 20120327@Elodie: change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20120405@Elodie: add @IsOverWrite param to comfirm that if the information of new feedback overwrite to current CRMInfo
		- 20120412@Elodie: check if @RelatedCustID <> NULL then update related customer.
		- 20120418@Elodie: remove condition to check if @RelatedCustID <> '' then update related customer.
						   change default value of @RelatedCustID param to NULL value
		- 20130121@Johnson: change linked server DB03 to DBPOLICY
	Param's Explanation:
		• @UpdateReviewedMode: Kind of update review
			0	Do nothing
			1	Update review
			2	remove review
		• @IsOverWrite: comfirm that if the information of new feedback overwrite to current CRMInfo.	
*/
BEGIN
	SET NOCOUNT ON	

	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[EditFeedback]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN

	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[FeedbackReview]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0 AND @UpdateReviewedMode IN (1,2)
		RETURN

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	IF NOT EXISTS (SELECT 1 FROM crmFeedback WITH(NOLOCK) WHERE FeedbackID = @FeedbackID)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Feedback does not exist.'
		RETURN
	END

	--- check to update customer info
	IF  @IsOverWrite = 1 AND
		EXISTS(	SELECT 1
				FROM crmCustomer c WITH(NOLOCK) 
				WHERE	CustID = @CustID 
						AND 
						(	FirstName <> @FirstName 
							OR
							LastName <> @LastName
							OR
							Phone <> @Phone
							OR
							MobilePhone <> @MobilePhone
							OR
							Fax <> @Fax
							OR
							Email <> @Email
							OR 
							Skype <> @Skype
							OR
							MSN <> @MSN
							OR
							Pic1 <> @Pic1
							OR
							Pic2 <> @Pic2
							OR
							Pic3 <> @Pic3
						)
			  )
	BEGIN
		EXEC [dbo].[Acc_CRM_CustomerShortUpd]
				@UserID				= @UserID,
				@CustID				= @CustID,
				@FirstName			= @FirstName,
				@LastName			= @LastName,
				@TitleID			= @TitleID,
				@Phone				= @Phone,
				@MobilePhone		= @MobilePhone,
				@Fax				= @Fax,			
				@Email				= @Email,					
				@Skype				= @Skype,
				@MSN				= @MSN,
				@IP					= @IP,
				@Pic1				= @Pic1,
				@Pic2				= @Pic2,
				@Pic3				= @Pic3,
				@ErrCode			= @ErrCode OUTPUT,
				@ErrMsg				= @ErrMsg OUTPUT
	END

	--- update feedback
	EXEC [dbo].[Acc_CRM_FeedbackUpd]
					@UserID				= @UserID, 
					@FeedbackID			= @FeedbackID, 
					@CustID				= @CustID, 
					@TitleID			= @TitleID, 
					@FirstName			= @FirstName, 
					@LastName			= @LastName, 
					@Phone				= @Phone, 
					@MobilePhone		= @MobilePhone, 
					@Fax				= @Fax, 
					@Email				= @Email, 
					@Skype				= @Skype,
					@MSN				= @MSN,
					@LanguageID			= @LanguageID, 
					@CountryID			= @CountryID, 
					@Subject			= @Subject,
					@FeedbackDate		= @FeedbackDate,
					@ResolutionDate		= @ResolutionDate, 
					@CommunicationID	= @CommunicationID, 
					@StationID			= @StationID, 
					@MainCategoryID		= @MainCategoryID, 
					@SubCategoryID		= @SubCategoryID, 
					@SiteID				= @SiteID, 
					@RoleID				= @RoleID, 
					@ProductID			= @ProductID, 
					@BettypeID			= @BettypeID, 
					@ResponseID			= @ResponseID, 
					@StatusID			= @StatusID, 
					@Description		= @Description, 
					@Solution			= @Solution, 
					@UpdateReviewedMode	= @UpdateReviewedMode, 
					@IsReviewed			= @IsReviewed, 
					@Review				= @Review, 
					@ReviewerID			= @ReviewerID, 
					@IP					= @IP,
					@Pic1				= @Pic1,	
					@Pic2				= @Pic2,
					@Pic3				= @Pic3,
					@ErrCode			= @ErrCode OUTPUT, 
					@ErrMsg				= @ErrMsg OUTPUT
	IF @ErrCode <> 0	
	BEGIN
		--SELECT @ErrCode = 100
		RETURN	
	END

	--- check for update related
	IF @RelatedCustID is not null
	BEGIN
		EXEC [dbo].[Acc_CRM_FeedbackCustomerUpd]
				@UserID			= @UserID,
				@FeedbackID		= @FeedbackID,
				@RelatedCustID	= @RelatedCustID,
				@IP				= @IP,
				@ErrCode		= @ErrCode,
				@ErrMsg			= @ErrMsg			
		IF @ErrCode <> 0
		BEGIN
			RETURN		
		END
	END
	
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackInfoUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackInfoUpd] TO [vnteam] 