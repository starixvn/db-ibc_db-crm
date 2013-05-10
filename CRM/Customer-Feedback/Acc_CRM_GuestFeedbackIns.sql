ALTER PROCEDURE [dbo].[Acc_CRM_GuestFeedbackIns]
(
	@UserID				INT,
	@UserName			NVARCHAR(50),
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
	@CreatorID			INT,
	@FeedbackDate		DATETIME		= NULL,	
	@ResolutionDate		DATETIME,
	@CommunicationID	INT,
	@StationID			INT,
	@MainCategoryID		INT,
	@SubCategoryID		INT,
	@SiteID				INT,
	@RoleID				INT				= 7004,
	@ProductID			INT,
	@BettypeID			INT,
	@ResponseID			INT,
	@StatusID			INT,
	@RelatedCustID		NVARCHAR(500)	= NULL,
	@Description		NVARCHAR(MAX),
	@Solution			NVARCHAR(MAX)	= '',
	@IsReviewed			BIT,
	@Review				NVARCHAR(4000)	= '',
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
	Date: 20101113
	Task : insert Guest's feedback
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20110628@Kevin: not update @RelatedCustID on [Acc_CRM_CustomerGuestIns] when insert a guest feedback
		- 20110629@Lukas: support multiple feedback related customer
		- 20120307@Elodie: add 3 params @Pic1, @Pic3, @Pic3
		- 20120319@Elodie: change DB06 to DB052
		- 20120327@Elodie: change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
						   change DB06 to DB052
		- 20120418@Elodie: change default value of @RelatedCustID param to NULL value
		- 20130121@Johnson: change linked server DB03 to DBPOLICY
	Param's Explanation:
		
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @CustID INT
	
	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[CreateFeedback]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[CustomerInfo]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN

	SELECT	@ErrCode = 0,
			@ErrMsg	 = ''
	--- create account for guest
	EXEC [dbo].[Acc_CRM_CustomerGuestIns]
					@UserID				= @UserID, 
					@CustID				= @CustID OUTPUT,
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
		SELECT @ErrCode = 100
		RETURN
	END
		
	--- insert feedback of guest
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
		SELECT @ErrCode = 101
		RETURN
	END

END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_GuestFeedbackIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_GuestFeedbackIns] TO [vnteam]