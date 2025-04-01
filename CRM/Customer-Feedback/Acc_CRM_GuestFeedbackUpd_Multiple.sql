/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE	[dbo].[Acc_CRM_GuestFeedbackUpd_Multiple] (
					@UserID						INT			
				,	@ListFeedbackID				VARCHAR(MAX)
				,	@CountryID					INT				= NULL
				,	@IsUpdateCountryID			BIT				= 0
				,	@SiteID						INT				= 0		
				,	@IsUpdateSiteID				BIT				= 0
				,	@Subject					NVARCHAR(200)	= NULL
				,	@IsUpdateSubject			BIT				= 0
				,	@LanguageID					INT				= NULL
				,	@IsUpdateLanguageID			BIT				= 0
				,	@UpdateReviewedMode			TINYINT			= 0
				,	@FeedbackDate				DATETIME		= NULL
				,	@IsUpdateFeedbackDate		BIT				= 0
				,	@FirstResponseTime			DATETIME		= NULL
				,	@IsUpdateFirstResponseTime	BIT				= 0
				,	@ResolutionDate				DATETIME		= NULL
				,	@IsUpdateResolutionDate		BIT				= 0
				,	@CommunicationID			VARCHAR(MAX)	= NULL
				,	@IsUpdateCommunicationID	BIT				= 0
				,	@StationID					VARCHAR(MAX)	= NULL
				,	@IsUpdateStationID			BIT				= 0
				,	@Category					VARCHAR(MAX)	= NULL
				,	@IsUpdateCategory			BIT				= 0
				,	@Product					VARCHAR(MAX)	= NULL
				,	@IsUpdateProduct			BIT				= 0
				,	@RoleID						INT				= 7004			
				,	@IsUpdateRoleID				BIT				= 0
				,	@ResponseID					INT				= NULL
				,	@IsUpdateResponseID			BIT				= 0
				,	@StatusID					INT				= NULL
				,	@IsUpdateStatusID			BIT				= 0
				,	@Description				NVARCHAR(MAX)	= ''
				,	@IsUpdateDescription		BIT				= 0
				,	@AutoField					NVARCHAR(MAX)	= ''
				,	@IsUpdateAutoField			BIT				= 0
				,	@Solution					NVARCHAR(MAX)	= ''
				,	@IsUpdateSolution			BIT				= 0
				,	@IsReviewed					BIT				= NULL
				,	@Review						NVARCHAR(MAX)	= ''
				,	@IsUpdateReview				BIT				= 0
				,	@ReviewerID					INT				= NULL
				,	@LicenseeType				INT				= 0		
				,	@IsUpdateLicenseeType		BIT				= 0
				,	@ProvinceID					INT				= NULL	
				,	@IsUpdateProvinceID			BIT				= 0
				,	@NoInquiries				SMALLINT		= NULL
				,	@IsUpdateNoInquiries		BIT				= 0
				,	@Rating						TINYINT			= 0
				,	@IsUpdateRating				BIT				= 0
				,	@IP							VARCHAR(15)		
				,	@ErrCode					INT				= 0 OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT
				)
AS
/*
	Created:	Winnie
	Date:		20170207
	Task :		Update multiple log [RedmineID:#68861]
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20180405@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20190813@Winnie: Update multiple enhancement RedmineID: #99434
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
		- 20250226@Virgil: CRM - Add Rating Column for Feedback [Redmine: #218235]
		- 20250320@Virgil: CRM - Add 1st Reponse Time for Feedback [Redmine: #220801]

	Param's Explanation:
		
*/
BEGIN	
	SET NOCOUNT ON;
				
DECLARE @tmpFeedbackID TABLE (FeedbackID INT)

INSERT INTO @tmpFeedbackID(FeedbackID)
	SELECT val
	FROM f_CRM_strSplit (@ListFeedbackID,',')		

DECLARE @SolveDate	DATETIME;


SELECT	@ErrCode	= 0
	,	@ErrMsg		= '';

IF	EXISTS (SELECT TOP 1 1 FROM @tmpFeedbackID t LEFT JOIN crmFeedback c WITH(NOLOCK) ON t.FeedbackID=c.FeedbackID WHERE c.FeedbackID IS NULL)
BEGIN
	SELECT	@ErrCode = 100
		,	@ErrMsg = 'Feedback does not exist.';

	RETURN;
END;


	WHILE EXISTS(SELECT TOP 1 FeedbackID FROM @tmpFeedbackID)
	BEGIN
	DECLARE @CustID INT,@FeedbackID INT
	SELECT TOP 1 @CustID= Custid,@FeedbackID=c.FeedbackID FROM 	crmFeedback c WITH(NOLOCK) INNER JOIN @tmpFeedbackID t ON c.FeedbackID=t.FeedbackID
	SELECT	@ErrCode = 0
		,	@ErrMsg	 = '';
	--- create account for guest

	--- insert feedback of guest 
	EXECUTE	dbo.Acc_CRM_FeedbackUpdMultiple
				@UserID					= @UserID
			,	@FeedbackID				= @FeedbackID			
			,	@CustID					= @CustID
			,	@LanguageID				= @LanguageID		
			,	@IsUpdateLanguageID		= @IsUpdateLanguageID					
			,	@CountryID				= @CountryID
			,	@IsUpdateCountryID		= @IsUpdateCountryID
			,	@Subject				= @Subject
			,	@IsUpdateSubject		= @IsUpdateSubject
			,	@FeedbackDate			= @FeedbackDate
			,	@IsUpdateFeedbackDate	= @IsUpdateFeedbackDate
			,	@FirstResponseTime		= @FirstResponseTime
			,	@IsUpdateFirstResponseTime = @IsUpdateFirstResponseTime
			,	@ResolutionDate			= @ResolutionDate
			,	@IsUpdateResolutionDate	= @IsUpdateResolutionDate
			,	@SiteID					= @SiteID
			,	@IsUpdateSiteID			= @IsUpdateSiteID
			,	@RoleID					= @RoleID
			,	@IsUpdateRoleID			= @IsUpdateRoleID
			,	@CommunicationID		= @CommunicationID
			,	@IsUpdateCommunicationID= @IsUpdateCommunicationID
			,	@StationID				= @StationID
			,	@IsUpdateStationID		= @IsUpdateStationID
			,	@Category				= @Category			
			,	@IsUpdateCategory		= @IsUpdateCategory		
			,	@Product				= @Product		
			,	@IsUpdateProduct		= @IsUpdateProduct
			,	@ResponseID				= @ResponseID
			,	@IsUpdateResponseID		= @IsUpdateResponseID
			,	@StatusID				= @StatusID
			,	@IsUpdateStatusID		= @IsUpdateStatusID		
			,	@Description			= @Description
			,	@IsUpdateDescription	= @IsUpdateDescription		
			,	@AutoField				= @AutoField
			,	@IsUpdateAutoField		= @IsUpdateAutoField
			,	@Solution				= @Solution
			,	@IsUpdateSolution		= @IsUpdateSolution	
			,	@UpdateReviewedMode		= @UpdateReviewedMode
			,	@IsReviewed				= @IsReviewed			
			,	@Review					= @Review
			,	@IsUpdateReview			= @IsUpdateReview		
			,	@ReviewerID				= @ReviewerID
			,	@IP						= @IP
			,	@LicenseeType			= @LicenseeType			
			,	@IsUpdateLicenseeType	= @IsUpdateLicenseeType		
			,	@ProvinceID				= @ProvinceID				
			,	@IsUpdateProvinceID		= @IsUpdateProvinceID
			,	@NoInquiries			= @NoInquiries
			,	@IsUpdateNoInquiries	= @IsUpdateNoInquiries
			,	@Rating					= @Rating
			,	@IsUpdateRating			= @IsUpdateRating
			,	@ErrCode				= @ErrCode				OUTPUT
			,	@ErrMsg					= @ErrMsg				OUTPUT;
					  
	IF	@ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = 101;
		SELECT	@ErrMsg  = 'Update failed'
		RETURN;
	END;
	DELETE FROM @tmpFeedbackID WHERE FeedbackID=@FeedbackID
	END

END
GO