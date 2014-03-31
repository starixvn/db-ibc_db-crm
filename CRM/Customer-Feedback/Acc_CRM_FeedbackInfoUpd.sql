
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_FeedbackInfoUpd    Script Date: 3/26/2014 6:06:06 PM ******/
CREATE PROCEDURE [dbo].[Acc_CRM_FeedbackInfoUpd]
(
	@UserID						INT,
	@FeedbackID					INT,
	@CustID						INT,
	@TitleID					INT,
	@Birthday					DATETIME = NULL,
	@FirstName					NVARCHAR(50)=NULL,
	@LastName					NVARCHAR(50)=NULL,
	@Phone						NVARCHAR(100)=NULL,
	@PhoneCountryCode			NVARCHAR(40)=NULL,
	@PhoneAreaCode				NVARCHAR(40)=NULL,
	@Phone2						NVARCHAR(100)=NULL,
	@Phone2CountryCode			NVARCHAR(40)=NULL,
	@Phone2AreaCode				NVARCHAR(40)=NULL,
	@Phone3						NVARCHAR(100)=NULL,
	@Phone3CountryCode			NVARCHAR(40)=NULL,
	@Phone3AreaCode				NVARCHAR(40)=NULL,
	@MobilePhone				NVARCHAR(100)=NULL,
	@MobilePhoneCountryCode		NVARCHAR(40)=NULL,
	@MobilePhoneAreaCode		NVARCHAR(40)=NULL,
	@Fax						NVARCHAR(50)=NULL,
	@FaxCountryCode				NVARCHAR(40)=NULL,
	@FaxAreaCode				NVARCHAR(40)=NULL,
	@Email						NVARCHAR(254)=NULL,
	@Skype						NVARCHAR(100)=NULL,
	@MSN						NVARCHAR(100)=NULL,
	@LanguageID					VARCHAR(1000),
	@CountryID					INT,
	@Subject					NVARCHAR(200)	= NULL,
	@RelatedCustID				NVARCHAR(500)	= NULL,
	@FeedbackDate				DATETIME,	
	@ResolutionDate				DATETIME,
	@CommunicationID			INT,
	@StationID					INT,
	@MainCategoryID				INT,
	@SubCategoryID				INT,
	@SiteID						INT,
	@RoleID						INT,
	@ProductID					INT,
	@BettypeID					INT,
	@ResponseID					INT,
	@StatusID					INT,
	@Description				NVARCHAR(MAX),
	@Solution					NVARCHAR(MAX),
	@UpdateReviewedMode			TINYINT = 0,
	@IsReviewed					BIT				= 0,
	@Review						NVARCHAR(4000),
	@ReviewerID					INT				= NULL,
	@IP							VARCHAR(15),
	@Pic1						NVARCHAR(100)	= NULL,
	@Pic2						NVARCHAR(100)	= NULL,
	@Pic3						NVARCHAR(100)	= NULL,
	@Pic4						NVARCHAR(100)	= NULL,
	@BettingCode				NVARCHAR(100)	= NULL,
	@RefCode2					NVARCHAR(100)	= NULL,
	@Passport					NVARCHAR(100)	= NULL,
	@IsVip						BIT,
	@ErrCode					INT				= 0 OUTPUT,
	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT,
	@IsOverWrite				BIT				= 0	
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
		- 20131108@Kathy: check required fields update to zero [Redmine:#7206]
		- 20140303@Dom: Modify for new structure
	Param's Explanation:
		• @UpdateReviewedMode: Kind of update review
			0	Do nothing
			1	Update review
			2	remove review
		• @IsOverWrite: comfirm that if the information of new feedback overwrite to current CRMInfo.	
*/
BEGIN
	SET NOCOUNT ON	

	IF NOT EXISTS (SELECT 1 FROM crmFeedback WITH(NOLOCK) WHERE FeedbackID = @FeedbackID)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Feedback does not exist.'
		RETURN
	END

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

	--- check to update customer info
	IF  @IsOverWrite = 1 
	BEGIN
		EXEC [dbo].[Acc_CRM_CustomerShortUpd]
				@UserID					= @UserID,
				@CustID					= @CustID,
				@FirstName				= @FirstName,
				@LastName				= @LastName,
				@TitleID				= @TitleID,
				@Birthday				= @Birthday,
				@Phone					= @Phone,
				@PhoneAreaCode			= @PhoneAreaCode,
				@PhoneCountryCode		= @PhoneCountryCode,
				@Phone2					= @Phone2,
				@Phone2AreaCode			= @Phone2AreaCode,
				@Phone2CountryCode		= @Phone2CountryCode,
				@Phone3					= @Phone3,
				@Phone3AreaCode			= @Phone3AreaCode,
				@Phone3CountryCode		= @Phone3CountryCode,
				@MobilePhone			= @MobilePhone,
				@MobilePhoneAreaCode	= @MobilePhoneAreaCode,
				@MobilePhoneCountryCode	= @MobilePhoneCountryCode,
				@Fax					= @Fax,
				@FaxAreaCode			= @FaxAreaCode,
				@FaxCountryCode			= @FaxCountryCode,
				@Email					= @Email,					
				@Skype					= @Skype,
				@MSN					= @MSN,
				@IP						= @IP,
				@Pic1					= @Pic1,
				@Pic2					= @Pic2,
				@Pic3					= @Pic3,
				@Pic4					= @Pic4,
				@BettingCode			= @BettingCode,
				@RefCode2				= @RefCode2,
				@Passport				= @Passport,
				@IsVip					= @IsVip,
				@SiteID					= @SiteID,
				@ErrCode				= @ErrCode OUTPUT,
				@ErrMsg					= @ErrMsg OUTPUT
	END

	--- update feedback
	EXEC [dbo].[Acc_CRM_FeedbackUpd]
					@UserID					= @UserID, 
					@FeedbackID				= @FeedbackID, 
					@CustID					= @CustID, 
					@TitleID				= @TitleID, 
					@Birthday				= @Birthday,
					@FirstName				= @FirstName, 
					@LastName				= @LastName, 
					@Phone					= @Phone,
					@PhoneAreaCode			= @PhoneAreaCode,
					@PhoneCountryCode		= @PhoneCountryCode,
					@Phone2					= @Phone2,
					@Phone2AreaCode			= @Phone2AreaCode,
					@Phone2CountryCode		= @Phone2CountryCode,
					@Phone3					= @Phone3,
					@Phone3AreaCode			= @Phone3AreaCode,
					@Phone3CountryCode		= @Phone3CountryCode,
					@MobilePhone			= @MobilePhone,
					@MobilePhoneAreaCode	= @MobilePhoneAreaCode,
					@MobilePhoneCountryCode	= @MobilePhoneCountryCode,
					@Fax					= @Fax,
					@FaxAreaCode			= @FaxAreaCode,
					@FaxCountryCode			= @FaxCountryCode,
					@Email					= @Email, 
					@BettingCode			= @BettingCode,
					@RefCode2				= @RefCode2,
					@Passport				= @Passport,
					@IsVip					= @IsVip,
					@Skype					= @Skype,
					@MSN					= @MSN,
					@LanguageID				= @LanguageID, 
					@CountryID				= @CountryID, 
					@Subject				= @Subject,
					@FeedbackDate			= @FeedbackDate,
					@ResolutionDate			= @ResolutionDate, 
					@CommunicationID		= @CommunicationID, 
					@StationID				= @StationID, 
					@MainCategoryID			= @MainCategoryID, 
					@SubCategoryID			= @SubCategoryID, 
					@SiteID					= @SiteID, 
					@RoleID					= @RoleID, 
					@ProductID				= @ProductID, 
					@BettypeID				= @BettypeID, 
					@ResponseID				= @ResponseID, 
					@StatusID				= @StatusID, 
					@Description			= @Description, 
					@Solution				= @Solution, 
					@UpdateReviewedMode		= @UpdateReviewedMode, 
					@IsReviewed				= @IsReviewed, 
					@Review					= @Review, 
					@ReviewerID				= @ReviewerID, 
					@IP						= @IP,
					@Pic1					= @Pic1,	
					@Pic2					= @Pic2,
					@Pic3					= @Pic3,
					@Pic4					= @Pic4,
					@RelatedCustID			= @RelatedCustID,
					@ErrCode				= @ErrCode OUTPUT, 
					@ErrMsg					= @ErrMsg OUTPUT
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

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackInfoUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackInfoUpd] TO [vnteam]
GO 
