/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_FeedbackInfoUpd (
					@UserID						INT
				,	@FeedbackID					INT
				,	@CustID						INT
				,	@TitleID					INT
				,	@Birthday					DATETIME		= NULL
				,	@FirstName					NVARCHAR(50)	= NULL
				,	@LastName					NVARCHAR(50)	= NULL
				,	@Phone						NVARCHAR(100)	= ''
				,	@PhoneCountryCode			NVARCHAR(40)	= ''
				,	@PhoneAreaCode				NVARCHAR(40)	= ''
				,	@Phone2						NVARCHAR(100)	= ''
				,	@Phone2CountryCode			NVARCHAR(40)	= ''
				,	@Phone2AreaCode				NVARCHAR(40)	= ''
				,	@Phone3						NVARCHAR(100)	= ''
				,	@Phone3CountryCode			NVARCHAR(40)	= ''
				,	@Phone3AreaCode				NVARCHAR(40)	= ''
				,	@MobilePhone				NVARCHAR(100)	= ''
				,	@MobilePhoneCountryCode		NVARCHAR(40)	= ''
				,	@MobilePhoneAreaCode		NVARCHAR(40)	= ''
				,	@Fax						NVARCHAR(50)	= NULL
				,	@FaxCountryCode				NVARCHAR(40)	= NULL
				,	@FaxAreaCode				NVARCHAR(40)	= NULL
				,	@Email						NVARCHAR(254)	= NULL
				,	@Skype						NVARCHAR(100)	= NULL
				,	@MSN						NVARCHAR(100)	= NULL
				,	@LanguageID					VARCHAR(1000)
				,	@CountryID					INT
				,	@Subject					NVARCHAR(200)	= NULL
				,	@RelatedCustID				VARCHAR(MAX)	= NULL
				,	@FeedbackDate				DATETIME
				,	@ResolutionDate				DATETIME
				,	@CommunicationID			VARCHAR(MAX)	
				,	@StationID					VARCHAR(MAX)
				,	@Category					VARCHAR(MAX)	
				,	@SiteID						INT
				,	@RoleID						INT
				,	@Product					VARCHAR(MAX)				
				,	@ResponseID					INT
				,	@StatusID					INT
				,	@Description				NVARCHAR(MAX)
				,	@AutoField					NVARCHAR(MAX)	= NULL
				,	@Solution					NVARCHAR(MAX)
				,	@UpdateReviewedMode			TINYINT = 0
				,	@IsReviewed					BIT				= 0
				,	@Review						NVARCHAR(MAX)
				,	@ReviewerID					INT				= NULL
				,	@IP							VARCHAR(15)
				,	@Pic1						NVARCHAR(100)	= NULL
				,	@Pic2						NVARCHAR(100)	= NULL
				,	@Pic3						NVARCHAR(100)	= NULL
				,	@Pic4						NVARCHAR(100)	= NULL
				,	@Pic1Name					NVARCHAR(100)	= NULL
				,	@Pic2Name					NVARCHAR(100)	= NULL
				,	@Pic3Name					NVARCHAR(100)	= NULL
				,	@Pic4Name					NVARCHAR(100)	= NULL
				,	@BettingCode				NVARCHAR(100)	= NULL
				,	@RefCode2					NVARCHAR(100)	= NULL
				,	@Passport					NVARCHAR(100)	= NULL
				,	@LicenseeType				INT				= 0
				,	@WhatsApp					NVARCHAR(100)	= NULL
				,	@Line						NVARCHAR(100)	= NULL
				,	@WeChat						NVARCHAR(100)	= NULL
				,	@Yahoo						NVARCHAR(100)	= NULL
				,	@QQ							NVARCHAR(100)	= NULL
				,	@BBM						NVARCHAR(100)	= NULL
				,	@ProvinceID					INT=NULL
				,	@ErrCode					INT				= 0		OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= ''	OUTPUT
				,	@IsOverWrite				BIT				= 0	
				,	@NoInquiries				SMALLINT		= NULL
)
AS
/*
	Created:	Lukas
	Date:		20101023
	Task:		update feedback info
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas:	support multiple feedback related customer
		- 20120307@Elodie:	add 3 params @Pic1, @Pic3, @Pic3
		- 20120319@Elodie:	change DB06 to DB052
		- 20120327@Elodie:	change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20120405@Elodie:	add @IsOverWrite param to comfirm that if the information of new feedback overwrite to current CRMInfo
		- 20120412@Elodie:	check if @RelatedCustID <> NULL then update related customer.
		- 20120418@Elodie:	remove condition to check if @RelatedCustID <> '' then update related customer.
							change default value of @RelatedCustID param to NULL value
		- 20130121@Johnson:	change linked server DB03 to DBPOLICY
		- 20131108@Kathy:	check required fields update to zero [Redmine:#7206]
		- 20140303@Dom:		Modify for new structure
		- 20141118@Dom:		add more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		- 20190506@Winnie:  CN88 Province RedmineID: #112637
		- 20190719@Winnie:  CRM - Remove limit Is Related Customer RedmineID: #113305
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
		- 20191104@Winnie:  [CRM] cannot search feedback of customer in manage feedback RedmineID: #123160
		- 20201021@Johnson: - remove limit amount for related customers
							- sync customer profile to CRM for related customers [redmine:#142194]
		- 20201119@Johnson:	check relatedCustomer <> '' to sync customer [redmine:#145661]
		- 20230412@Winfred: NAP CRM - Some of our Headline Contact info was missing in CRM [redmine:#186726]		
		- 20230418@Winfred: CRM - Update Feedback > Auto update Isvip=0 when checking Overwrite then Update FB [redmine:#187064]			
	Param's Explanation:
		- @UpdateReviewedMode: Kind of update review
			0	Do nothing
			1	Update review
			2	remove review
		- @IsOverWrite: comfirm that if the information of new feedback overwrite to current CRMInfo.	
*/
BEGIN
	SET NOCOUNT ON;	

	IF	NOT EXISTS (SELECT 1 FROM crmFeedback WITH (NOLOCK) WHERE FeedbackID = @FeedbackID)
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Feedback does not exist.';

		RETURN;
	END;

	IF	ISNULL(@CommunicationID, '') = ''
	OR	ISNULL(@Category, '') = ''
	OR	ISNULL(@Product, '') = ''
	OR	ISNULL(@StatusID, 0) = 0 
	OR	ISNULL(@LanguageID, 0) = 0
	OR	ISNULL(@RoleID, 0) = 0
	OR	ISNULL(@ResponseID, 0) = 0
	OR	ISNULL(@StationID, '') = ''
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Incorrect Data.';

		RETURN;
	END;
	DECLARE @IsVip BIT

	--- check to update customer info
	IF  @IsOverWrite = 1 
	BEGIN
		SELECT	
			@IsVip = IsVip		
		FROM crmCustomer WITH(NOLOCK)
		WHERE CustID = @CustID

		EXECUTE	dbo.Acc_CRM_CustomerShortUpd
					@UserID					= @UserID
				,	@CustID					= @CustID
				,	@FirstName				= @FirstName
				,	@LastName				= @LastName
				,	@TitleID				= @TitleID
				,	@Birthday				= @Birthday
				,	@Phone					= @Phone
				,	@PhoneAreaCode			= @PhoneAreaCode
				,	@PhoneCountryCode		= @PhoneCountryCode
				,	@Phone2					= @Phone2
				,	@Phone2AreaCode			= @Phone2AreaCode
				,	@Phone2CountryCode		= @Phone2CountryCode
				,	@Phone3					= @Phone3
				,	@Phone3AreaCode			= @Phone3AreaCode
				,	@Phone3CountryCode		= @Phone3CountryCode
				,	@MobilePhone			= @MobilePhone
				,	@MobilePhoneAreaCode	= @MobilePhoneAreaCode
				,	@MobilePhoneCountryCode	= @MobilePhoneCountryCode
				,	@Fax					= @Fax
				,	@FaxAreaCode			= @FaxAreaCode
				,	@FaxCountryCode			= @FaxCountryCode
				,	@Email					= @Email
				,	@SiteID					= @SiteID
				,	@Skype					= @Skype
				,	@MSN					= @MSN
				,	@IP						= @IP
				,	@Pic1					= @Pic1
				,	@Pic2					= @Pic2
				,	@Pic3					= @Pic3
				,	@Pic4					= @Pic4
				,	@Pic1Name				= @Pic1Name
				,	@Pic2Name				= @Pic2Name
				,	@Pic3Name				= @Pic3Name
				,	@Pic4Name				= @Pic4Name
				,	@BettingCode			= @BettingCode
				,	@RefCode2				= @RefCode2
				,	@Passport				= @Passport
				,	@IsVip					= @IsVip
				,	@LicenseeType			= @LicenseeType
				,	@WhatsApp				= @WhatsApp
				,	@Line					= @Line
				,	@WeChat					= @WeChat
				,	@Yahoo					= @Yahoo
				,	@QQ						= @QQ
				,	@BBM					= @BBM
				,	@ErrCode				= @ErrCode OUTPUT
				,	@ErrMsg					= @ErrMsg OUTPUT;
	END;

	SELECT	
		@IsVip = IsVip		
	FROM crmFeedback WITH(NOLOCK)
	WHERE FeedbackID = @FeedbackID AND CustID = @CustID
	--- update feedback
	EXECUTE	dbo.Acc_CRM_FeedbackUpd
				@UserID					= @UserID
			,	@FeedbackID				= @FeedbackID
			,	@CustID					= @CustID
			,	@TitleID				= @TitleID
			,	@Birthday				= @Birthday
			,	@FirstName				= @FirstName
			,	@LastName				= @LastName
			,	@Phone					= @Phone
			,	@PhoneAreaCode			= @PhoneAreaCode
			,	@PhoneCountryCode		= @PhoneCountryCode
			,	@Phone2					= @Phone2
			,	@Phone2AreaCode			= @Phone2AreaCode
			,	@Phone2CountryCode		= @Phone2CountryCode
			,	@Phone3					= @Phone3
			,	@Phone3AreaCode			= @Phone3AreaCode
			,	@Phone3CountryCode		= @Phone3CountryCode
			,	@MobilePhone			= @MobilePhone
			,	@MobilePhoneAreaCode	= @MobilePhoneAreaCode
			,	@MobilePhoneCountryCode	= @MobilePhoneCountryCode
			,	@Fax					= @Fax
			,	@FaxAreaCode			= @FaxAreaCode
			,	@FaxCountryCode			= @FaxCountryCode
			,	@Email					= @Email
			,	@BettingCode			= @BettingCode
			,	@RefCode2				= @RefCode2
			,	@Passport				= @Passport
			,	@IsVip					= @IsVip
			,	@Skype					= @Skype
			,	@MSN					= @MSN
			,	@LanguageID				= @LanguageID
			,	@CountryID				= @CountryID
			,	@ProvinceID				= @ProvinceID
			,	@Subject				= @Subject
			,	@FeedbackDate			= @FeedbackDate
			,	@ResolutionDate			= @ResolutionDate
			,	@CommunicationID		= @CommunicationID
			,	@StationID				= @StationID
			,	@Category				= @Category		
			,	@SiteID					= @SiteID
			,	@RoleID					= @RoleID
			,	@Product				= @Product			
			,	@ResponseID				= @ResponseID
			,	@StatusID				= @StatusID
			,	@Description			= @Description
			,	@AutoField				= @AutoField
			,	@Solution				= @Solution
			,	@UpdateReviewedMode		= @UpdateReviewedMode
			,	@IsReviewed				= @IsReviewed
			,	@Review					= @Review
			,	@ReviewerID				= @ReviewerID
			,	@IP						= @IP
			,	@Pic1					= @Pic1
			,	@Pic2					= @Pic2
			,	@Pic3					= @Pic3
			,	@Pic4					= @Pic4
			,	@Pic1Name				= @Pic1Name
			,	@Pic2Name				= @Pic2Name
			,	@Pic3Name				= @Pic3Name
			,	@Pic4Name				= @Pic4Name
			,	@RelatedCustID			= @RelatedCustID
			,	@LicenseeType			= @LicenseeType
			,	@WhatsApp				= @WhatsApp
			,	@Line					= @Line
			,	@WeChat					= @WeChat
			,	@Yahoo					= @Yahoo
			,	@NoInquiries			= @NoInquiries
			,	@QQ						= @QQ
			,	@BBM					= @BBM
			,	@IsOverWrite			= @IsOverWrite
			,	@ErrCode				= @ErrCode OUTPUT
			,	@ErrMsg					= @ErrMsg OUTPUT;
	IF	@ErrCode <> 0	
	BEGIN
		--SELECT @ErrCode = 100
		RETURN;	
	END;
	
	--- check for update related
	IF	ISNULL(@RelatedCustID,'') <> ''
	BEGIN
		--Sync profile for related customers to CRM
		DECLARE	@relatedCustomer TABLE(CustID INT, 								
									username VARCHAR(50),
									FirstName NVARCHAR(100),
									LastName NVARCHAR(100),
									phone NVARCHAR(100),
									MobilePhone NVARCHAR(100),
									Fax NVARCHAR(100),
									Email NVARCHAR(100),
									Birthday SMALLDATETIME,
									CountryID INT,
									SiteID INT,
									isExistsCRM BIT DEFAULT(0), 
									isFinished BIT DEFAULT(0));

		INSERT INTO	@relatedCustomer(custid)
		SELECT	CONVERT(INT, val)
		FROM	dbo.f_CRM_strSplit(@RelatedCustID, ',');

		UPDATE t
		SET isExistsCRM = 1 
		FROM @relatedCustomer t
			INNER JOIN crmCustomer cm WITH(NOLOCK) ON t.custid = cm.custid
		
		IF EXISTS (SELECT 1 FROM @relatedCustomer WHERE isExistsCRM = 0)
		BEGIN
			DECLARE @r_CustID INT,
					@r_username VARCHAR(50),
					@r_FirstName NVARCHAR(100),
					@r_LastName NVARCHAR(100),
					@r_phone NVARCHAR(100),
					@r_MobilePhone NVARCHAR(100),
					@r_Fax NVARCHAR(100),
					@r_Email NVARCHAR(100),
					@r_Birthday SMALLDATETIME,
					@r_CountryID INT,
					@r_SiteID INT
				
			UPDATE t
			SET t.custid = c.custid,
				t.username = c.username,
				t.FirstName = c.FirstName,
				t.LastName = c.LastName, 
				t.phone = c.phone,
				t.MobilePhone = c.MobilePhone,
				t.Fax = c.Fax,
				t.Email = c.Email,
				t.Birthday = c.Birthday,
				t.CountryID = ct.CountryID,
				t.SiteID = (SELECT SettingID 
							FROM crmSetting WITH(NOLOCK) 
							WHERE SettingValue = ISNULL(c.site,ag.site)
								AND SettingName IN( 'Site','SiteCategory')
							)
			FROM @relatedCustomer t
				INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid
				LEFT JOIN bodb02.dbo.Customer ag WITH(NOLOCK) ON c.recommend = ag.custid
				LEFT JOIN crmCountry ct ON c.country = ct.CountryName
			WHERE isExistsCRM = 0	
			
			WHILE (1=1)
			BEGIN 
				UPDATE TOP (1) t
				SET isFinished = 1,
					@r_Custid = custid,
					@r_username = username,
					@r_FirstName = FirstName,
					@r_LastName = LastName, 
					@r_phone = phone,
					@r_MobilePhone = MobilePhone,
					@r_Fax = Fax,
					@r_Email = Email,
					@r_Birthday = Birthday,
					@r_CountryID = CountryID,
					@r_SiteID = siteID
				FROM @relatedCustomer t
				WHERE isFinished = 0
					AND isExistsCRM = 0
					
				IF @@ROWCOUNT = 0
					BREAK;
					
				EXECUTE	dbo.Acc_CRM_CustomerIns_New
						@UserID					= @UserID
					,	@CustID					= @r_CustID
					,	@UserName				= @r_UserName
					,	@FirstName				= @r_FirstName
					,	@LastName				= @r_LastName			
					,	@Birthday				= @r_Birthday				
					,	@Phone					= @r_Phone	
					,	@MobilePhone			= @r_MobilePhone				
					,	@Fax					= @r_Fax				
					,	@Email					= @r_Email				
					,	@CountryID				= @r_CountryID				
					,	@SiteID					= @r_SiteID
					,	@CreatorID				= @UserID
					
					,	@IP						= @IP
					,	@ErrCode				= @ErrCode OUTPUT
					,	@ErrMsg					= @ErrMsg OUTPUT;
				IF @ErrCode <> 0
				BEGIN
					--SELECT @ErrCode = 100
					RETURN;
				END;	
			END
		END
		
		EXECUTE	dbo.Acc_CRM_FeedbackCustomerUpd
					@UserID			= @UserID
				,	@FeedbackID		= @FeedbackID
				,	@RelatedCustID	= @RelatedCustID
				,	@IP				= @IP
				,	@ErrCode		= @ErrCode
				,	@ErrMsg			= @ErrMsg;			
		IF	@ErrCode <> 0
		BEGIN
			RETURN;		
		END;
	END;
	
END;
GO
