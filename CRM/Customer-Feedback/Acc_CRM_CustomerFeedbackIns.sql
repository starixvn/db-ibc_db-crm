ALTER PROCEDURE [dbo].[Acc_CRM_CustomerFeedbackIns]
(
	@UserID				INT,
	@CustID				INT,
	@UserName			NVARCHAR(50),
	@TitleID			INT				= NULL,
	@FirstName			NVARCHAR(50)	= NULL,
	@LastName			NVARCHAR(50)	= NULL,
	@Phone				NVARCHAR(50)	= NULL,
	@MobilePhone		NVARCHAR(50)	= NULL,
	@Fax				NVARCHAR(50)	= NULL,
	@Email				NVARCHAR(254)	= NULL,
	@Skype				NVARCHAR(100)	= NULL,
	@MSN				NVARCHAR(100)	= NULL,
	@LanguageID			INT				= NULL,
	@CountryID			INT				= NULL,	
	@CreatorID			INT,
	@Subject			NVARCHAR(200)	= NULL,
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
	@RelatedCustID		VARCHAR(500)	= NULL,
	@Description		NVARCHAR(MAX)	= NULL,
	@Solution			NVARCHAR(MAX)	= NULL,
	@IsReviewed			BIT				= 0,
	@Review				NVARCHAR(4000)	= NULL,
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
	Task : insert feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas: support multiple related customer
		- 20120307@Elodie: add 3 params @Pic1, @Pic3, @Pic3
		- 20120309@Elodie: format @Skype, @MSN, @Pic1, @Pic2, @Pic3, @O_Skype, @O_MSN, @O_Pic1, @O_Pic2, @O_Pic3 values
		- 20120319@Elodie: change DB06 to DB052
		- 20120327@Elodie: change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20120404@Elodie: not overwrite the Contact information when adding new feedback to current CRM Info
		- 20120405@Elodie: add @IsOverWrite param to comfirm that if the information of new feedback overwrite to current CRMInfo
		- 20120418@Elodie: change default value of @RelatedCustID param to NULL value
		- 20130121@Johnson: Change link server DB03 to DBPOLICY
		- 20131108@Kathy: check required fields update to zero [Redmine:#7206]
	Param's Explanation:
		• @IsOverWrite: comfirm that if the information of new feedback overwrite to current CRMInfo.	
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @FeedbackID	INT,
			@SolveDate	DATETIME

--	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[CustomerInfo]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN

	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[CreateFeedback]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''	

	IF ISNULL(@CommunicationID,0) = 0 
		or ISNULL(@MainCategoryID,0) = 0 
		or ISNULL(@SubCategoryID,0) = 0 
		or ISNULL(@StatusID,0) = 0 
		or ISNULL(@LanguageID,0) = 0
		or ISNULL(@RoleID,0) = 0
		or ISNULL(@ResponseID,0) = 0
		or ISNULL(@StationID,0) = 0
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Incorrect Data.'
		RETURN
	END

	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		---- insert new customer
		EXEC dbo.Acc_CRM_CustomerIns
				@UserID				= @UserID,
				@CustID				= @CustID,
				@UserName			= @UserName,
				@FirstName			= @FirstName,
				@LastName			= @LastName,
				@TitleID			= @TitleID,
				@LanguageID			= @LanguageID,
				@Phone				= @Phone,
				@MobilePhone		= @MobilePhone,
				@Fax				= @Fax,
				@Email				= @Email,
				@Skype				= @Skype,
				@MSN				= @MSN,
				@CountryID			= @CountryID,
				@IsVIP				= 0,
				@SiteID				= @SiteID,				
				@CreatorID			= @CreatorID,
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
	END	
	ELSE
	BEGIN
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
	END

	-- insert feedback	
	EXEC [dbo].[Acc_CRM_FeedbackIns]
					@UserID				= @UserID, 
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
					@CreatorID			= @CreatorID, 
					@FeedbackDate		= @FeedbackDate, 
					@ResolutionDate	    = @ResolutionDate,
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
					@RelatedCustID		= @RelatedCustID, 
					@Description		= @Description, 
					@Solution			= @Solution, 
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
		--SELECT @ErrCode = 101
		RETURN
	END
END



GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerFeedbackIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerFeedbackIns] TO [vnteam]