ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackIns]
(
	@UserID				INT,
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
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
	Created: Lukas
	Date: 20101023
	Task : insert feedback
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas: support multiple feedback related customer
		- 20120307@Elodie: add 3 params @Pic1, @Pic3, @Pic3
		- 20120314@Elodie: check condition that feedback related customer must be different to customer of feedback
		- 20120319@Elodie: change DB06 to DB052
		- 20120327@Elodie: change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20120418@Elodie: change default value of @RelatedCustID param to NULL value
		- 20120529@Elodie: encode some parameters to write log in XML format, such as Pic1, Pic2, Pic3
	Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @FeedbackID	INT,
			@SolveDate	DATETIME				

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''
	
	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		SELECT	@ErrCode = 101, 
				@ErrMsg = 'Customer does not exist.'
		RETURN
	END	

	-- get solve date
	SELECT @SolveDate = CASE WHEN @IsReviewed = 0 THEN NULL ELSE GETDATE() END


	-- insert feedback
	INSERT INTO crmFeedback
				(
					CustID, 
					TitleID, 
					FirstName, 
					LastName, 
					Phone, 
					MobilePhone, 
					Fax, 
					Email,
					Skype,
					MSN,
					LanguageID, 
					CountryID, 
					CreateDate, 
					CreatorID, 
					FeedbackDate, 
					SolveDate,
					CommunicationID, 
					StationID, 
					MainCategoryID, 
					SubCategoryID, 
					SiteID, 
					RoleID, 
					ProductID,
					BetTypeID, 
					ResponseID, 
					StatusID, 
					Description, 
					Solution, 
					IsReviewed, 
					Review, 
					ReviewerID,
					Subject,
					ResolutionDate,
					Pic1,
					Pic2,
					Pic3
				)
			VALUES
				(
					@CustID, 
					@TitleID, 
					@FirstName, 
					@LastName, 
					@Phone, 
					@MobilePhone, 
					@Fax, 
					@Email,
					@Skype,
					@MSN,
					@LanguageID, 
					@CountryID, 
					GETDATE(), 
					@CreatorID, 
					@FeedbackDate, 
					@SolveDate,
					@CommunicationID, 
					@StationID, 
					@MainCategoryID, 
					@SubCategoryID, 
					@SiteID, 
					@RoleID, 
					@ProductID,
					@BetTypeID, 
					@ResponseID, 
					@StatusID, 
					@Description, 
					@Solution, 
					@IsReviewed, 
					@Review, 
					@ReviewerID,
					@Subject,
					@ResolutionDate,
					@Pic1,
					@Pic2,
					@Pic3
				)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'Insert feedback unsuccessfuly.'
		RETURN
	END

	-- insert to crmFeedback customer
	SELECT @FeedbackID = @@identity	
	INSERT INTO crmFeedbackCustomer
				(
					FeedbackID, 
					CustID, 
					IsRelated
				)
			VALUES
				(
					@FeedbackID, 
					@CustID, 
					0
				)
	IF @@ERROR <> 0
	BEGIN
		-- rollback
		DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Insert feedback unsuccessfuly.'
		RETURN
	END

	IF @RelatedCustID IS NOT NULL AND @RelatedCustID <> ''
	BEGIN
		DECLARE @relatedCustomer TABLE(CustID INT)

		INSERT INTO @relatedCustomer
				SELECT CONVERT(INT,val)
				FROM [dbo].[f_split](@RelatedCustID,',')

		-- insert feedback related
		INSERT INTO crmFeedbackCustomer(FeedbackID, CustID, IsRelated)	
								SELECT DISTINCT @FeedbackID, CustID, 1
								FROM @relatedCustomer where CustID <> @CustID

		IF @@ERROR <> 0
		BEGIN
			-- rollback
			DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID
			DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID

			SELECT @ErrCode = 105
			SELECT @ErrMsg = 'Insert feedback unsuccessfuly.'
			RETURN
		END
	END	

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_FeedbackIns>' + --SP Name
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
						'<Creator>'			+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')		+ '</Creator>' +
						'<FeedbackDate>'	+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate),'')		+ '</FeedbackDate>' +
						'<ResolutionDate>'	+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate),'')	+ '</ResolutionDate>' +
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
						'<RelatedCustID>'	+ ISNULL(@RelatedCustID,'')							+ '</RelatedCustID>' +
						'<IsReviewed>'		+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')		+ '</IsReviewed>' +
						'<Reviewer>'		+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')		+ '</Reviewer>' +						
						'<Pic1>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1),'')		+ '</Pic1>' +
						'<Pic2>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2),'')		+ '</Pic2>' +
						'<Pic3>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3),'')		+ '</Pic3>' +
					'</Acc_CRM_FeedbackIns>'


	EXEC [dbo].[WriteLog_UserLog_crmLogFeedback]
					@UserID = @UserID, 
					@FeedbackID = @FeedbackID,
					@CustID = @CustID,  
					@ActionID = 200, 
					@IP = @IP, 
					@Description = @Description, 
					@Solution = @Solution,
					@Review =  @Review,
					@Doing = @LogElement
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackIns] TO [vnteam]