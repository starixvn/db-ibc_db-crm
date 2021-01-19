/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	[dbo].[Acc_CRM_CustomerFeedbackIns] (
					@UserID						INT
				,	@CustID						INT
				,	@UserName					NVARCHAR(50)
				,	@TitleID					INT				= NULL
				,	@Birthday					DATETIME		= NULL
				,	@FirstName					NVARCHAR(50)	= NULL
				,	@LastName					NVARCHAR(50)	= NULL
				,	@Phone						NVARCHAR(100)	= NULL
				,	@PhoneCountryCode			NVARCHAR(40)	= NULL
				,	@PhoneAreaCode				NVARCHAR(40)	= NULL
				,	@Phone2						NVARCHAR(100)	= NULL
				,	@Phone2CountryCode			NVARCHAR(40)	= NULL
				,	@Phone2AreaCode				NVARCHAR(40)	= NULL
				,	@Phone3						NVARCHAR(100)	= NULL
				,	@Phone3CountryCode			NVARCHAR(40)	= NULL
				,	@Phone3AreaCode				NVARCHAR(40)	= NULL
				,	@MobilePhone				NVARCHAR(100)	= NULL
				,	@MobilePhoneCountryCode		NVARCHAR(40)	= NULL
				,	@MobilePhoneAreaCode		NVARCHAR(40)	= NULL
				,	@Fax						NVARCHAR(50)	= NULL
				,	@FaxCountryCode				NVARCHAR(40)	= NULL
				,	@FaxAreaCode				NVARCHAR(40)	= NULL
				,	@Email						NVARCHAR(254)	= NULL
				,	@Passport					VARCHAR(100)	= NULL
				,	@Skype						NVARCHAR(100)	= NULL
				,	@MSN						NVARCHAR(100)	= NULL
				,	@LanguageID					INT				= NULL
				,	@CountryID					INT				= NULL
				,	@BettingCode				NVARCHAR(100)	= NULL
				,	@RefCode2					NVARCHAR(100)	= NULL
				,	@IsVip						BIT				= NULL
				,	@CreatorID					INT
				,	@Subject					NVARCHAR(200)	= NULL
				,	@FeedbackDate				DATETIME
				,	@ResolutionDate				DATETIME
				,	@CommunicationID			VARCHAR(MAX)	
				,	@StationID					VARCHAR(MAX)	
				,	@Category					VARCHAR(MAX)		
				,	@Product					VARCHAR(MAX)	
				,	@SiteID						INT
				,	@RoleID						INT			
				,	@ResponseID					INT
				,	@StatusID					INT
				,	@RelatedCustID				VARCHAR(MAX)	= NULL
				,	@Description				NVARCHAR(MAX)	= NULL
				,	@AutoField					NVARCHAR(MAX)	= NULL
				,	@Solution					NVARCHAR(MAX)	= NULL
				,	@IsReviewed					BIT				= 0
				,	@Review						NVARCHAR(MAX)	= NULL
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
				,	@LicenseeType				INT				= 0
				,	@WhatsApp					NVARCHAR(100)	= NULL
				,	@Line						NVARCHAR(100)	= NULL
				,	@WeChat						NVARCHAR(100)	= NULL
				,	@Yahoo						NVARCHAR(100)	= NULL
				,	@QQ							NVARCHAR(100)	= NULL
				,	@BBM						NVARCHAR(100)	= NULL
				,	@ErrCode					INT				= 0 OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT
				,	@IsOverWrite				BIT				= 0
				,	@ProvinceID					INT				= NULL
				,	@NoInquiries				SMALLINT		= NULL
				,	@MessageID 					INT 			= 0
				,	@RequestIDs					VARCHAR(1000)	= ''
				,	@ListOrigCustIDs 			VARCHAR(MAX)	= ''
				)
AS
/*
	Created:	Lukas
	Date:		20101023
	Task :		insert feedback
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas:	support multiple related customer
		- 20120307@Elodie:	add 3 params @Pic1, @Pic3, @Pic3
		- 20120309@Elodie:	format @Skype, @MSN, @Pic1, @Pic2, @Pic3, @O_Skype, @O_MSN, @O_Pic1, @O_Pic2, @O_Pic3 values
		- 20120319@Elodie:	change DB06 to DB052
		- 20120327@Elodie:	change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20120404@Elodie:	not overwrite the Contact information when adding new feedback to current CRM Info
		- 20120405@Elodie:	add @IsOverWrite param to comfirm that if the information of new feedback overwrite to current CRMInfo
		- 20120418@Elodie:	change default value of @RelatedCustID param to NULL value
		- 20130121@Johnson:	Change link server DB03 to DBPOLICY
		- 20131108@Kathy:	check required fields update to zero [Redmine:#7206]
		- 20140303@Dom:		Modify for new structure
		- 20141118@Dom:		add more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]	
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20190628@Winnie: CN88 Permission Fix bug RedmineID: #115828
		- 20190719@Winnie: CRM - Remove limit Is Related Customer: #113305
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
		- 20200603@Johnson: check duplicate feedback from auto service [redmine: #135337]
		- 20200901@Johnson: add requestid to check missing auto void request [redmine:#139158]	
		- 20201020@Johnson: - remove checking limit related customers 
							- sync customer profile to CRM for related customers [redmine:#142194]
		- 20210113@Johnson: check empty @RelatedCustID [redmine:#148690]					
	Param's Explanation:
		- @IsOverWrite: comfirm that if the information of new feedback overwrite to current CRMInfo.	
		- @MessageID : MsgID from Auto fb service, each time just process 1 msgid with only 1 headline
		- @ListOrigCustIDs: list custid have void tickets from auto fb service	
*/
BEGIN	
	SET NOCOUNT ON;

	DECLARE @FeedbackID	INT,
			@SolveDate	DATETIME;

	IF	ISNULL(@CommunicationID, '') = ''
	OR	ISNULL(@Category, '') = '' 	
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
	
	IF	NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		---- insert new customer
		EXECUTE	dbo.Acc_CRM_CustomerIns_New
					@UserID					= @UserID
				,	@CustID					= @CustID
				,	@UserName				= @UserName
				,	@FirstName				= @FirstName
				,	@LastName				= @LastName
				,	@TitleID				= @TitleID
				,	@Birthday				= @Birthday
				,	@LanguageID				= @LanguageID
				,	@Phone					= @Phone
				,	@PhoneCountryCode		= @PhoneCountryCode
				,	@PhoneAreaCode			= @PhoneAreaCode
				,	@Phone2					= @Phone2
				,	@Phone2CountryCode		= @Phone2CountryCode
				,	@Phone2AreaCode			= @Phone2AreaCode
				,	@Phone3					= @Phone3
				,	@Phone3CountryCode		= @Phone3CountryCode
				,	@Phone3AreaCode			= @Phone3AreaCode
				,	@MobilePhone			= @MobilePhone
				,	@MobilePhoneCountryCode	= @MobilePhoneCountryCode
				,	@MobilePhoneAreaCode	= @MobilePhoneAreaCode
				,	@Fax					= @Fax
				,	@FaxCountryCode			= @FaxCountryCode
				,	@FaxAreaCode			= @FaxAreaCode
				,	@Email					= @Email
				,	@Passport				= @Passport
				,	@BettingCode			= @BettingCode
				,	@RefCode2				= @RefCode2
				,	@Skype					= @Skype
				,	@MSN					= @MSN
				,	@CountryID				= @CountryID
				,	@IsVIP					= @IsVIP
				,	@SiteID					= @SiteID
				,	@CreatorID				= @CreatorID
				,	@LicenseeType			= @LicenseeType
				,	@WhatsApp				= @WhatsApp
				,	@Line					= @Line
				,	@WeChat					= @WeChat
				,	@Yahoo					= @Yahoo
				,	@QQ						= @QQ
				,	@BBM					= @BBM
				,	@IP						= @IP
				,	@Pic1					= @Pic1
				,	@Pic2					= @Pic2
				,	@Pic3					= @Pic3
				,	@Pic4					= @Pic4
				,	@ProvinceID				= @ProvinceID
				,	@ErrCode				= @ErrCode OUTPUT
				,	@ErrMsg					= @ErrMsg OUTPUT;
		IF @ErrCode <> 0
		BEGIN
			--SELECT @ErrCode = 100
			RETURN;
		END;
	END;	
	ELSE
	BEGIN
		--- check to update customer info
		IF	@IsOverWrite = 1
		BEGIN
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
	END; 
	
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
	
	IF ISNULL(@RelatedCustID,'') <> ''
	BEGIN
		INSERT INTO	@relatedCustomer(custid)
		SELECT	CONVERT(INT, val)
		FROM	dbo.f_CRM_strSplit(@RelatedCustID, ',');
		
		UPDATE t
		SET isExistsCRM = 1 
		FROM @relatedCustomer t
			INNER JOIN crmCustomer cm WITH(NOLOCK) ON t.custid = cm.custid
	END 
	
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
				,	@CreatorID				= @CreatorID
				
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
	
	-- insert feedback	
	EXECUTE	dbo.Acc_CRM_FeedbackIns
				@UserID					= @UserID
			,	@CustID					= @CustID
			,	@UserName				= @UserName
			,	@TitleID				= @TitleID
			,	@Birthday				= @Birthday
			,	@FirstName				= @FirstName
			,	@LastName				= @LastName
			,	@Phone					= @Phone
			,	@PhoneCountryCode		= @PhoneCountryCode
			,	@PhoneAreaCode			= @PhoneAreaCode
			,	@Phone2					= @Phone2
			,	@Phone2CountryCode		= @Phone2CountryCode
			,	@Phone2AreaCode			= @Phone2AreaCode
			,	@Phone3					= @Phone3
			,	@Phone3CountryCode		= @Phone3CountryCode
			,	@Phone3AreaCode			= @Phone3AreaCode
			,	@MobilePhone			= @MobilePhone
			,	@MobilePhoneCountryCode	= @MobilePhoneCountryCode
			,	@MobilePhoneAreaCode	= @MobilePhoneAreaCode
			,	@Fax					= @Fax
			,	@FaxCountryCode			= @FaxCountryCode
			,	@FaxAreaCode			= @FaxAreaCode
			,	@Email					= @Email
			,	@Skype					= @Skype
			,	@MSN					= @MSN
			,	@CountryID				= @CountryID
			,	@Pic1					= @Pic1
			,	@Pic2					= @Pic2
			,	@Pic3					= @Pic3
			,	@Pic4					= @Pic4
			,	@Pic1Name				= @Pic1Name
			,	@Pic2Name				= @Pic2Name
			,	@Pic3Name				= @Pic3Name
			,	@Pic4Name				= @Pic4Name
			,	@Passport				= @Passport
			,	@SiteID					= @SiteID
			,	@BettingCode			= @BettingCode
			,	@RefCode2				= @RefCode2
			,	@IsVip					= @IsVip
			,	@LanguageID				= @LanguageID
			,	@CreatorID				= @CreatorID
			,	@Subject				= @Subject
			,	@FeedbackDate			= @FeedbackDate
			,	@ResolutionDate			= @ResolutionDate
			,	@CommunicationID		= @CommunicationID
			,	@StationID				= @StationID
			,	@Category				= @Category		
			,	@RoleID					= @RoleID
			,	@Product				= @Product			
			,	@ResponseID				= @ResponseID
			,	@StatusID				= @StatusID
			,	@RelatedCustID			= @RelatedCustID
			,	@Description			= @Description
			,	@AutoField				= @AutoField
			,	@Solution				= @Solution
			,	@IsReviewed				= @IsReviewed
			,	@Review					= @Review
			,	@ReviewerID				= @ReviewerID
			,	@LicenseeType			= @LicenseeType
			,	@WhatsApp				= @WhatsApp
			,	@Line					= @Line
			,	@WeChat					= @WeChat
			,	@Yahoo					= @Yahoo
			,	@QQ						= @QQ
			,	@BBM					= @BBM
			,	@IP						= @IP
			,	@ProvinceID				= @ProvinceID
			,	@NoInquiries			= @NoInquiries
			, 	@MessageID				= @MessageID
			,	@RequestIDs				= @RequestIDs
			,	@ListOrigCustIDs		= @ListOrigCustIDs
			,	@ErrCode				= @ErrCode OUTPUT
			,	@ErrMsg					= @ErrMsg OUTPUT;
	IF	@ErrCode <> 0
	BEGIN
		--SELECT @ErrCode = 101
		RETURN;
	END;
END;

