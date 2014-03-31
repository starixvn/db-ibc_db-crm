
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CommunicationLogUpd    Script Date: 3/26/2014 6:06:04 PM ******/
CREATE PROCEDURE [dbo].[Acc_CRM_CommunicationLogUpd]
	@FeedbackID			INT,
	@CustID				INT,
	@RelatedCustID		VARCHAR(500) = NULL,
	@LanguageID			INT,
    @CountryID			INT,
    @FeedbackDate		DATETIME,
	@ResolutionDate		DATETIME,
    @CommunicationID	INT,
    @StationID			INT,
    @MainCategoryID		INT,
    @SubCategoryID		INT,
    @SiteID				INT,
    @RoleID				INT,
    @ProductID			INT,
    @BetTypeID			INT,
    @ResponseID			INT,
    @StatusID			INT,
    @Description		NVARCHAR(MAX),
    @Solution			NVARCHAR(MAX),
    @IsReviewed			BIT,
    @Review				NVARCHAR(4000) = NULL,
    @ReviewerID			INT,
    @Subject			NVARCHAR(200),
	@UserID				INT,
	@IP					VARCHAR(15),
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT
AS

/*
Created: 20140127@Dom
Task : Insert new customer log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
*/
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

DECLARE @CustID_Old				INT,
		@RelatedCustID_Old			VARCHAR(500),
		@LanguageID_Old				INT,
		@CountryID_Old				INT,
		@ResolutionDate_Old			DATETIME,
		@FeedbackDate_Old			DATETIME,
		@CommunicationID_Old		INT,
		@StationID_Old				INT,
		@MainCategoryID_Old			INT,
		@SubCategoryID_Old			INT,
		@SiteID_Old					INT,
		@RoleID_Old					INT,
		@ProductID_Old				INT,
		@BetTypeID_Old				INT,
		@ResponseID_Old				INT,
		@StatusID_Old				INT,
		@Description_Old			NVARCHAR(MAX),
		@Solution_Old				NVARCHAR(MAX),
		@IsReviewed_Old				BIT,
		@Review_Old					NVARCHAR(4000),
		@ReviewerID_Old				INT,
		@Subject_Old				NVARCHAR(200)

SELECT	@CustID_Old				=CustID,							
		@CountryID_Old			=CountryID,			
		@LanguageID_Old			=LanguageID,
		@ResolutionDate_Old		=ResolutionDate,		
		@FeedbackDate_Old		=FeedbackDate,				
		@CommunicationID_Old	=CommunicationID,	
		@StationID_Old			=StationID,			
		@MainCategoryID_Old		=MainCategoryID,		
		@SubCategoryID_Old		=SubCategoryID,		
		@SiteID_Old				=SiteID,				
		@RoleID_Old				=RoleID,				
		@ProductID_Old			=ProductID,			
		@BetTypeID_Old			=BetTypeID,			
		@ResponseID_Old			=ResponseID,			
		@StatusID_Old			=StatusID,			
		@Description_Old		=Description,		
		@Solution_Old			=Solution,			
		@IsReviewed_Old			=IsReviewed,			
		@Review_Old				=Review,				
		@ReviewerID_Old			=ReviewerID,			
		@Subject_Old			=Subject			
FROM crmFeedback WITH(NOLOCK)
WHERE FeedbackID = @FeedbackID

SELECT @RelatedCustID_Old = '';
SELECT @RelatedCustID_Old = @RelatedCustID_Old+CAST(fbc.CustID AS VARCHAR(1000))+','
FROM crmFeedbackCustomer(NOLOCK) fbc
WHERE fbc.FeedbackID = @FeedbackID AND fbc.IsRelated=1
IF ISNULL(@RelatedCustID_Old,'')<>''
SELECT @RelatedCustID_Old = LEFT(@RelatedCustID_Old,LEN(@RelatedCustID_Old)-1)

IF @IsReviewed_Old = 0 AND @IsReviewed = 1
	SET @ReviewerID = @UserID

UPDATE crmFeedback WITH(ROWLOCK,UPDLOCK)
SET LanguageID			= @LanguageID,
	CountryID			= @CountryID,
	ResolutionDate		= @ResolutionDate,
	FeedbackDate		= @FeedbackDate,
	CommunicationID		= @CommunicationID,
	StationID			= @StationID,
	MainCategoryID		= @MainCategoryID,
	SubCategoryID		= @SubCategoryID,
	SiteID				= @SiteID,
	RoleID				= @RoleID,
	ProductID			= @ProductID,
	BetTypeID			= @BetTypeID,
	ResponseID			= @ResponseID,
	StatusID			= @StatusID,
	Description			= @Description,
	Solution			= @Solution,
	IsReviewed			= @IsReviewed,
	Review				= @Review,
	ReviewerID			= @ReviewerID,
	Subject				= @Subject
WHERE FeedbackID = @FeedbackID

IF @@ERROR <> 0
	BEGIN
		-- rollback
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Update feedback unsuccessfuly.'
		RETURN
	END

	--IF @RelatedCustID IS NOT NULL AND @RelatedCustID <> ''
	--BEGIN

		DECLARE @relatedCustomer TABLE(CustID INT)

		INSERT INTO @relatedCustomer
		SELECT CONVERT(INT,val)
		FROM [dbo].[f_split](@RelatedCustID,',')
		
		DELETE crmFeedbackCustomer WITH(ROWLOCK,UPDLOCK) WHERE FeedbackID = @FeedbackID and IsRelated = 1
		-- insert feedback related
		INSERT INTO crmFeedbackCustomer(FeedbackID, CustID, IsRelated)	
								SELECT DISTINCT @FeedbackID, CustID, 1
								FROM @relatedCustomer where CustID <> @CustID

		IF @@ERROR <> 0
		BEGIN
			
			SELECT @ErrCode = 105
			SELECT @ErrMsg = 'Update feedback unsuccessfuly.'
			RETURN
		END
	--END

	-- Write Log
	DECLARE @NewValues XML,@OldValues XML
	
	SELECT @OldValues = 				
					'<Acc_CRM_CommunicationLogUpd>' + 
							'<CustID>'						+ ISNULL(CONVERT(VARCHAR(5),@CustID_Old),'')						+'</CustID>' +
							'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID_Old),'')					+ '</LanguageID>' +
							'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID_Old),'')					+ '</CountryID>' +
							'<Subject>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Subject_Old),'')					+ '</Subject>' +
							'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Description_Old),'')										+ '</Remark>' +
							'<Solution>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Solution_Old),'')											+ '</Solution>' +
							'<Review>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Review_Old),'')											+ '</Review>' +
							'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate_Old),'')				+ '</ResolutionDate>' +
							'<FeedbackDate>'				+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate_Old),'')					+ '</FeedbackDate>' +
							'<CommunicationID>'				+ ISNULL(CONVERT(VARCHAR(10),@CommunicationID_Old),'')				+ '</CommunicationID>' +
							'<StationID>'					+ ISNULL(CONVERT(VARCHAR(10),@StationID_Old),'')					+ '</StationID>' +
							'<MainCategoryID>'				+ ISNULL(CONVERT(VARCHAR(10),@MainCategoryID_Old),'')				+ '</MainCategoryID>' +
							'<SubCategoryID>'				+ ISNULL(CONVERT(VARCHAR(10),@SubCategoryID_Old),'')				+ '</SubCategoryID>' +
							'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')						+ '</SiteID>' +
							'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID_Old),'')						+ '</RoleID>' +
							'<ProductID>'					+ ISNULL(CONVERT(VARCHAR(10),@ProductID_Old),'')					+ '</ProductID>' +
							'<BettypeID>'					+ ISNULL(CONVERT(VARCHAR(10),@BettypeID_Old),'')					+ '</BettypeID>' +
							'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID_Old),'')					+ '</ResponseID>' +
							'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID_Old),'')						+ '</StatusID>' +
							'<RelatedCustID>'				+ ISNULL(@RelatedCustID_Old,'')										+ '</RelatedCustID>' +
							'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed_Old),'')					+ '</IsReviewed>' +
							'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID_Old),'')					+ '</Reviewer>' +					
					'</Acc_CRM_CommunicationLogUpd>'
	 
	 
	SELECT @NewValues=
					'<Acc_CRM_CommunicationLogUpd>' + 
							'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')					+ '</LanguageID>' +
							'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')					+ '</CountryID>' +
							'<Subject>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Subject),'')					+ '</Subject>' +
							'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Description),'')										+ '</Remark>' +
							'<Solution>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Solution),'')											+ '</Solution>' +
							'<Review>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Review),'')											+ '</Review>' +
							'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate),'')				+ '</ResolutionDate>' +
							'<FeedbackDate>'				+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate),'')					+ '</FeedbackDate>' +
							'<CommunicationID>'				+ ISNULL(CONVERT(VARCHAR(10),@CommunicationID),'')				+ '</CommunicationID>' +
							'<StationID>'					+ ISNULL(CONVERT(VARCHAR(10),@StationID),'')					+ '</StationID>' +
							'<MainCategoryID>'				+ ISNULL(CONVERT(VARCHAR(10),@MainCategoryID),'')				+ '</MainCategoryID>' +
							'<SubCategoryID>'				+ ISNULL(CONVERT(VARCHAR(10),@SubCategoryID),'')				+ '</SubCategoryID>' +
							'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')						+ '</SiteID>' +
							'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID),'')						+ '</RoleID>' +
							'<ProductID>'					+ ISNULL(CONVERT(VARCHAR(10),@ProductID),'')					+ '</ProductID>' +
							'<BettypeID>'					+ ISNULL(CONVERT(VARCHAR(10),@BettypeID),'')					+ '</BettypeID>' +
							'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID),'')					+ '</ResponseID>' +
							'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')						+ '</StatusID>' +
							'<RelatedCustID>'				+ ISNULL(@RelatedCustID,'')										+ '</RelatedCustID>' +
							'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')					+ '</IsReviewed>' +
							'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')					+ '</Reviewer>' +					
					'</Acc_CRM_CommunicationLogUpd>'
			
	EXEC [dbo].[WriteLog_UserLog_crmLogFeedback]
					@UserID = @UserID, 
					@FeedbackID = @FeedbackID,
					@CustID = @CustID,  
					@ActionID = 203, 
					@IP = @IP, 
					@Description = @Description, 
					@Solution = @Solution,
					@Review =  @Review,
					@NewValues = @NewValues,
					@OldValues = @OldValues
					
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CommunicationLogUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CommunicationLogUpd] TO [vnteam]
GO 
