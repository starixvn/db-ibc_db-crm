ALTER PROCEDURE [dbo].[Acc_CRM_CustomerFeedbackIns]
(
	@UserID						INT,
	@CustID						INT,
	@UserName					NVARCHAR(50),
	@TitleID					INT				= NULL,
	@Birthday					DATETIME		= NULL,
	@FirstName					NVARCHAR(50)	= NULL,
	@LastName					NVARCHAR(50)	= NULL,
	@Phone						NVARCHAR(100)	= NULL,
	@PhoneCountryCode			NVARCHAR(40)	= NULL,
	@PhoneAreaCode				NVARCHAR(40)	= NULL,
	@Phone2						NVARCHAR(100)	= NULL,
	@Phone2CountryCode			NVARCHAR(40)	= NULL,
	@Phone2AreaCode				NVARCHAR(40)	= NULL,
	@Phone3						NVARCHAR(100)	= NULL,
	@Phone3CountryCode			NVARCHAR(40)	= NULL,
	@Phone3AreaCode				NVARCHAR(40)	= NULL,
	@MobilePhone				NVARCHAR(100)	= NULL,
	@MobilePhoneCountryCode		NVARCHAR(40)	= NULL,
	@MobilePhoneAreaCode		NVARCHAR(40)	= NULL,
	@Fax						NVARCHAR(50)	= NULL,
	@FaxCountryCode				NVARCHAR(40)	= NULL,
	@FaxAreaCode				NVARCHAR(40)	= NULL,
	@Email						NVARCHAR(254)	= NULL,
	@Passport					VARCHAR(100)	= NULL,
	@Skype						NVARCHAR(100)	= NULL,
	@MSN						NVARCHAR(100)	= NULL,
	@LanguageID					INT				= NULL,
	@CountryID					INT				= NULL,	
	@BettingCode				NVARCHAR(100)	= NULL,
	@RefCode2					NVARCHAR(100)	= NULL,
	@IsVip						BIT				= NULL,
	@CreatorID					INT,
	@Subject					NVARCHAR(200)	= NULL,
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
	@RelatedCustID				VARCHAR(500)	= NULL,
	@Description				NVARCHAR(MAX)	= NULL,
	@Solution					NVARCHAR(MAX)	= NULL,
	@IsReviewed					BIT				= 0,
	@Review						NVARCHAR(MAX)	= NULL,
	@ReviewerID					INT				= NULL,
	@IP							VARCHAR(15),
	@Pic1						NVARCHAR(100)	= NULL,
	@Pic2						NVARCHAR(100)	= NULL,
	@Pic3						NVARCHAR(100)	= NULL,
	@Pic4						NVARCHAR(100)	= NULL,
	@ErrCode					INT				= 0 OUTPUT,
	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT,
	@IsOverWrite				BIT				= 0
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
		- 20140303@Dom: Modify for new structure
	Param's Explanation:
		• @IsOverWrite: comfirm that if the information of new feedback overwrite to current CRMInfo.	
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @FeedbackID	INT,
			@SolveDate	DATETIME

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
		EXEC dbo.Acc_CRM_CustomerIns_New
				@UserID					= @UserID,
				@CustID					= @CustID,
				@UserName				= @UserName,
				@FirstName				= @FirstName,
				@LastName				= @LastName,
				@TitleID				= @TitleID,
				@Birthday				= @Birthday,
				@LanguageID				= @LanguageID,
				@Phone					= @Phone,
				@PhoneCountryCode		= @PhoneCountryCode,
				@PhoneAreaCode			= @PhoneAreaCode,
				@Phone2					= @Phone2,
				@Phone2CountryCode		= @Phone2CountryCode,
				@Phone2AreaCode			= @Phone2AreaCode,
				@Phone3					= @Phone3,
				@Phone3CountryCode		= @Phone3CountryCode,
				@Phone3AreaCode			= @Phone3AreaCode,
				@MobilePhone			= @MobilePhone,
				@MobilePhoneCountryCode	= @MobilePhoneCountryCode,
				@MobilePhoneAreaCode	= @MobilePhoneAreaCode,
				@Fax					= @Fax,
				@FaxCountryCode			= @FaxCountryCode,
				@FaxAreaCode			= @FaxAreaCode,
				@Email					= @Email,
				@Passport				= @Passport,
				@BettingCode			= @BettingCode,
				@RefCode2				= @RefCode2,
				@Skype					= @Skype,
				@MSN					= @MSN,
				@CountryID				= @CountryID,
				@IsVIP					= @IsVIP,
				@SiteID					= @SiteID,				
				@CreatorID				= @CreatorID,
				@IP						= @IP,
				@Pic1					= @Pic1,
				@Pic2					= @Pic2,
				@Pic3					= @Pic3,
				@Pic4					= @Pic4,
				@ErrCode				= @ErrCode OUTPUT,
				@ErrMsg					= @ErrMsg OUTPUT
		IF @ErrCode <> 0
		BEGIN
			--SELECT @ErrCode = 100
			RETURN
		END
	END	
	ELSE
	BEGIN
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
					@SiteID					= @SiteID,
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
					@ErrCode				= @ErrCode OUTPUT,
					@ErrMsg					= @ErrMsg OUTPUT
		END
	END 
	PRINT @birthday
	-- insert feedback	
	EXEC [dbo].[Acc_CRM_FeedbackIns]
					@UserID					= @UserID,
					@CustID					= @CustID,
					@UserName				= @UserName,
					@TitleID				= @TitleID,
					@Birthday				= @Birthday,
					@FirstName				= @FirstName,
					@LastName				= @LastName,
					@Phone					= @Phone,
					@PhoneCountryCode		= @PhoneCountryCode,
					@PhoneAreaCode			= @PhoneAreaCode,
					@Phone2					= @Phone2,
					@Phone2CountryCode		= @Phone2CountryCode,
					@Phone2AreaCode			= @Phone2AreaCode,
					@Phone3					= @Phone3,
					@Phone3CountryCode		= @Phone3CountryCode,
					@Phone3AreaCode			= @Phone3AreaCode,
					@MobilePhone			= @MobilePhone,
					@MobilePhoneCountryCode	= @MobilePhoneCountryCode	,
					@MobilePhoneAreaCode	= @MobilePhoneAreaCode,
					@Fax					= @Fax,
					@FaxCountryCode			= @FaxCountryCode,
					@FaxAreaCode			= @FaxAreaCode,
					@Email					= @Email,
					@Skype					= @Skype,
					@MSN					= @MSN,
					@CountryID				= @CountryID,	
					@Pic1					= @Pic1,
					@Pic2					= @Pic2,
					@Pic3					= @Pic3,
					@Pic4					= @Pic4,
					@Passport				= @Passport,
					@SiteID					= @SiteID,
					@BettingCode			= @BettingCode,
					@RefCode2				= @RefCode2,
					@IsVip					= @IsVip,
					@LanguageID				= @LanguageID,
					@CreatorID				= @CreatorID,
					@Subject				= @Subject,
					@FeedbackDate			= @FeedbackDate,
					@ResolutionDate			= @ResolutionDate,
					@CommunicationID		= @CommunicationID,
					@StationID				= @StationID,
					@MainCategoryID			= @MainCategoryID,
					@SubCategoryID			= @SubCategoryID,
					@RoleID					= @RoleID,
					@ProductID				= @ProductID,
					@BettypeID				= @BettypeID,
					@ResponseID				= @ResponseID,
					@StatusID				= @StatusID,
					@RelatedCustID			= @RelatedCustID,
					@Description			= @Description,
					@Solution				= @Solution,
					@IsReviewed				= @IsReviewed,
					@Review					= @Review,
					@ReviewerID				= @ReviewerID,
					@IP						= @IP,
					@ErrCode				= @ErrCode OUTPUT,
					@ErrMsg					= @ErrMsg OUTPUT
	IF @ErrCode <> 0
	BEGIN
		--SELECT @ErrCode = 101
		RETURN
	END
END

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerFeedbackIns] TO [bodbAdminNet]
GO 
