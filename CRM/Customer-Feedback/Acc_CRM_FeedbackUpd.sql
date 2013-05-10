ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackUpd]
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
	@Review				NVARCHAR(4000)	= NULL,
	@ReviewerID			INT				= NULL,	
	@IP					VARCHAR(15),	
	@Pic1				NVARCHAR(100)	= NULL,
	@Pic2				NVARCHAR(100)	= NULL,
	@Pic3				NVARCHAR(100)	= NULL,
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
	Created: Lukas
	Date: 20101023
	Task : update feedback
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20120307@Elodie: add 3 params @Pic1, @Pic3, @Pic3
		- 20120319@Elodie: change DB06 to DB052
		- 20120327@Elodie: change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20120529@Elodie: encode some parameters to write log in XML format, such as Subject, Pic1, Pic2, ...
	Param's Explanation:
		- @UpdateReviewedMode: Kind of update review
			0	Do nothing
			1	Update review
			2	remove review
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @SolveDate	DATETIME

	
	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	IF NOT EXISTS (SELECT 1 FROM crmFeedback WITH(NOLOCK) WHERE FeedbackID = @FeedbackID)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Feedback does not exist.'
		RETURN
	END

	SELECT 
		@SolveDate	= CASE	WHEN @UpdateReviewedMode = 0 THEN SolveDate 
							WHEN @UpdateReviewedMode = 1 THEN GETDATE() 
							WHEN @UpdateReviewedMode = 2 THEN NULL 
							ELSE SolveDate
					  END,
		@Review		= CASE	WHEN @UpdateReviewedMode = 0 THEN Review 
							WHEN @UpdateReviewedMode = 1 THEN @Review 
							WHEN @UpdateReviewedMode = 2 THEN NULL
							ELSE Review 
					  END,
		@IsReviewed = CASE	WHEN @UpdateReviewedMode = 0 THEN IsReviewed 
							WHEN @UpdateReviewedMode = 1 THEN 1
							WHEN @UpdateReviewedMode = 2 THEN 0
							ELSE IsReviewed 
					  END,
		@ReviewerID = CASE	WHEN @UpdateReviewedMode = 0 THEN ReviewerID 
							WHEN @UpdateReviewedMode = 1 THEN @ReviewerID
							WHEN @UpdateReviewedMode = 2 THEN NULL
							ELSE ReviewerID 
					  END
	FROM 
		crmFeedback WITH(NOLOCK)
	WHERE 
		FeedbackID = @FeedbackID

	--- update feedback
	UPDATE crmFeedback WITH(ROWLOCK,UPDLOCK)
	SET  CustID				= @CustID, 
		 TitleID			= @TitleID, 
		 FirstName			= @FirstName, 
		 LastName			= @LastName, 
		 Phone				= @Phone, 
		 MobilePhone		= @MobilePhone, 
		 Fax				= @Fax, 
		 Email				= @Email, 
		 Skype				= @Skype,
		 msn				= @MSN,
		 LanguageID			= @LanguageID, 
		 CountryID			= @CountryID,
		 Subject			= @Subject,
		 FeedbackDate		= @FeedbackDate,
		 ResolutionDate		= @ResolutionDate, 
		 SolveDate			= @SolveDate, 
		 CommunicationID	= @CommunicationID, 
		 StationID			= @StationID, 
		 MainCategoryID		= @MainCategoryID, 
		 SubCategoryID		= @SubCategoryID, 
		 SiteID				= @SiteID, 
		 RoleID				= @RoleID, 
		 ProductID			= @ProductID, 
		 BetTypeID			= @BetTypeID, 
		 ResponseID			= @ResponseID, 
		 StatusID			= @StatusID, 
		 Description		= @Description, 
		 Solution			= @Solution, 
		 IsReviewed			= @IsReviewed, 
		 Review				= @Review, 
		 ReviewerID			= @ReviewerID,
		 Pic1				= @Pic1,
		 Pic2				= @Pic2,
		 Pic3				= @Pic3					
	WHERE 
		FeedbackID = @FeedbackID
	 
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'updated feedback unsuccessfuly.'
		RETURN
	END


	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_FeedbackUpd>' + --SP Name
						'<Title>'			+ ISNULL(CONVERT(VARCHAR(5),@TitleID),'')			+ '</Title>' +
						'<FirstName>'		+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName),'')	+ '</FirstName>' +
						'<LastName>'		+ ISNULL([dbo].[f_EncodeXMLValue](@LastName),'')	+ '</LastName>' +
						'<Phone>'			+ ISNULL(@Phone,'')									+ '</Phone>' +
						'<MobilePhone>'		+ ISNULL(@MobilePhone,'')							+ '</MobilePhone>' +
						'<Fax>'				+ ISNULL(@Fax,'')									+ '</Fax>' +
						'<Email>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Email),'')		+ '</Email>' +
						'<Skype>'			+ ISNULL(@Skype,'')									+ '</Skype>' +
						'<MSN>'				+ ISNULL(@MSN,'')									+ '</MSN>' +
						'<LanguageID>'		+ ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')		+ '</LanguageID>' +
						'<CountryID>'		+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')		+ '</CountryID>' +
						'<Subject>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Subject),'')		+ '</Subject>' +
						'<FeedbackDate>'	+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate),'')		+ '</FeedbackDate>' +
						'<SolveDate>'		+ ISNULL(CONVERT(VARCHAR(20),@SolveDate),'')		+ '</SolveDate>' +
						'<CommunicationID>' + ISNULL(CONVERT(VARCHAR(10),@CommunicationID),'')	+ '</CommunicationID>' +
						'<StationID>'		+ ISNULL(CONVERT(VARCHAR(10),@StationID),'')		+ '</StationID>' +
						'<MainCategoryID>'	+ ISNULL(CONVERT(VARCHAR(10),@MainCategoryID),'')	+ '</MainCategoryID>' +
						'<SubCategoryID>'	+ ISNULL(CONVERT(VARCHAR(10),@SubCategoryID),'')	+ '</SubCategoryID>' +
						'<SiteID>'			+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')			+ '</SiteID>' +
						'<RoleID>'			+ ISNULL(CONVERT(VARCHAR(10),@RoleID),'')			+ '</RoleID>' +
						'<ProductID>'		+ ISNULL(CONVERT(VARCHAR(10),@ProductID),'')		+ '</ProductID>' +
						'<BettypeID>'		+ ISNULL(CONVERT(VARCHAR(10),@BettypeID),'')		+ '</BettypeID>' +
						'<ResponseID>'		+ ISNULL(CONVERT(VARCHAR(10),@ResponseID),'')		+ '</ResponseID>' +
						'<StatusID>'		+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')			+ '</StatusID>' +
						'<IsReviewed>'		+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')		+ '</IsReviewed>' +
						'<ReviewerID>'		+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')		+ '</ReviewerID>' +
						'<Pic1>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1),'')		+ '</Pic1>' +
						'<Pic2>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2),'')		+ '</Pic2>' +
						'<Pic3>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3),'')		+ '</Pic3>' +
					'</Acc_CRM_FeedbackUpd>'


	EXEC [dbo].[WriteLog_UserLog_crmLogFeedback]
					@UserID = @UserID, 
					@FeedbackID = @FeedbackID,
					@CustID = @CustID,  
					@ActionID = 201, 
					@IP = @IP, 
					@Description = @Description, 
					@Solution = @Solution,
					@Review =  @Review,
					@Doing = @LogElement

END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackUpd] TO [vnteam]