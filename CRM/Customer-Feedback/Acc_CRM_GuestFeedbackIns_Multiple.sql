/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_GuestFeedbackIns_Multiple] @UserID INT
	,@UserRole TINYINT = 2
	,@ListCustID VARCHAR(MAX) = NULL
	,@Subject NVARCHAR(200) = NULL
	,@CreatorID INT
	,@FeedbackDate DATETIME = NULL
	,@ResolutionDate DATETIME
	,@StationID VARCHAR(MAX)
	,@Category VARCHAR(MAX)
	,@Categorystr VARCHAR(MAX)
	,@SubCategorystr VARCHAR(MAX)
	,@Product VARCHAR(MAX)
	,@CommunicationID VARCHAR(MAX) = ''
	,@ResponseID INT
	,@StatusID INT
	,@Description NVARCHAR(MAX)
	,@AutoField NVARCHAR(MAX) = NULL
	,@AutoField1 NVARCHAR(MAX) = ''
	,@AutoField2 NVARCHAR(MAX) = ''
	,@AutoField3 NVARCHAR(MAX) = ''
	,@Solution NVARCHAR(MAX) = ''
	,@IsReviewed BIT
	,@Review NVARCHAR(MAX) = ''
	,@ReviewerID INT = NULL
	,@IP VARCHAR(15)
	,@NoInquiries SMALLINT = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(4000) = '' OUTPUT
	,@IsCheckedDefaultComm BIT = 0
	,@RelatedCustomers NVARCHAR(MAX) = NULL
	,@MessageID 		INT 			= 0
	,@WinLimitLogID		BIGINT			= 0	
	,@TOControlLogID	VARCHAR(MAX)	= ''
	,@PALogID			VARCHAR(MAX)	= ''
	,@AmendmentLogID	INT	= 0
	,@RequestIDs		VARCHAR(1000)	= ''
	,@ListOrigCustIDs 	VARCHAR(MAX)	= ''
	,@IsManualMultiple  BIT = 0
	,@CountryName	NVARCHAR(300) = ''
	,@LanguageID INT = 0
AS
/*
	Created:	Winnie
	Date:		20170207
	Task :		insert multiple log [RedmineID:#68861]
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20180405@Winnie:  Allow users to select multiple products/sub-categories - Redmine: #84714
		- 20190711@Elodie:  CN88 Permission - edmineID: #112637]
		- 20190905@Winnie: CRM - Left panel did not show Super, Master, Agent  [RedmineId: #119708]
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
		- 20191007@Winnie: CRM - Create multiple logs got inconsistency between username and custid  [RedmineId: #121540]
		- 20191021@Winnie: CRM - Support Default Communication Tool  [RedmineId: #122078]
		- 20200311@Tim: Support "is related customers" function in Create Multiple Logs - RedmineId: #129144
		- 20200603@Johnson: check duplicate feedback from auto service [redmine: #135337]
		- 20200901@Johnson: add requestid to check missing auto void request [redmine:#139158]	
		- 20201020@Johnson: add WinlimitLogid for auto feedback company win limit
							and remove checking limit related customers [redmine:#142194]
		- 20201130@Johnson: add @TOControlLogID for auto feedback TO Control [redmine:#145274]					
		- 20210125@Johnson: check existing before sync related customers [redmine:#149205]
		- 202010303@Winfred: Add AmendmentLogID [redmine:#147470]
		- 20210510@Johnson: add @PALogID for auto feedback Problem account [redmine:#153119]
		- 20210517@Johnson: Add param @IsManualMultiple to check duplicate fb [redmine:#155102]
		- 20210426@Winfred: Offer Country & Language checkbox like Communication Tool on Multiple Logs function [redmine:#153458]
		
	Param's Explanation:
		@RelatedCustomers: <ROOT><Row CustId='1' RelatedCustId='2' Username='test' /></ROOT>
		@MessageID : MsgID from Auto fb service, each time just process 1 msgid with only 1 headline
		@WinLimitLogID: LogID from winlimit auto fb service, process 1 logid with 1 headline
		@TOControlLogID for auto fb TO control service
		@PALogID for auto fb Problem account service
		@AmendmentLogID LogID from Amendment notification auto fb service, process 1 logid with 1 feedback
		@ListOrigCustIDs: list custid have void tickets from auto fb service	
*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@Categorystr, '') = ''
		OR ISNULL(@Category, '') = ''
		OR ISNULL(@Product, '') = ''
		OR ISNULL(@StatusID, 0) = 0
		OR ISNULL(@SubCategorystr, '') = ''
		OR ISNULL(@ResponseID, 0) = 0
		OR ISNULL(@StationID, '') = ''
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'Incorrect Data.'

		RETURN
	END

	DECLARE @tmpUsername TABLE (CustId INT PRIMARY KEY, Username NVARCHAR(50))
	CREATE TABLE #tblComm (CommID INT)
	CREATE TABLE #tblRelatedCustomer (CustId INT, 
									RelatedCustId INT, 
									Username NVARCHAR(50),
									FirstName NVARCHAR(100),
									LastName NVARCHAR(100),
									phone NVARCHAR(100),
									MobilePhone NVARCHAR(100),
									Fax NVARCHAR(100),
									Email NVARCHAR(100),
									Birthday SMALLDATETIME,
									CountryID INT,
									SiteID INT,									
									isFinished BIT DEFAULT(0)
									)
									
	DECLARE @iDoc INT

	EXEC sp_xml_preparedocument @iDoc OUTPUT
		,@ListCustID

	INSERT INTO @tmpUsername (CustId, Username)
	SELECT CustId, Username
	FROM OPENXML(@iDoc, '/ROOT/Cust', 1) WITH (CustId INT, Username NVARCHAR(50))

	EXEC sp_xml_removedocument @iDoc

	IF ISNULL(@RelatedCustomers, '') <> ''
	BEGIN
		EXEC sp_xml_preparedocument @iDoc OUTPUT
			,@RelatedCustomers

		INSERT INTO #tblRelatedCustomer (CustId, RelatedCustId, Username)
		SELECT CustId, RelatedCustId, Username
		FROM OPENXML(@iDoc, '/ROOT/Row', 1) WITH (CustId INT, RelatedCustId INT, Username NVARCHAR(50))

		EXEC sp_xml_removedocument @iDoc
	END

	DECLARE @CustID INT
		,@TitleID INT
		,@FirstName NVARCHAR(50)
		,@LastName NVARCHAR(50)
		,@Birthday DATETIME
		,@Phone NVARCHAR(50)
		,@PhoneCountryCode NVARCHAR(20)
		,@PhoneAreaCode NVARCHAR(20)
		,@Phone2 NVARCHAR(100)
		,@Phone2CountryCode NVARCHAR(20)
		,@Phone2AreaCode NVARCHAR(20)
		,@Phone3 NVARCHAR(100)
		,@Phone3CountryCode NVARCHAR(20)
		,@Phone3AreaCode NVARCHAR(20)
		,@MobilePhone NVARCHAR(50)
		,@MobilePhoneCountryCode NVARCHAR(20)
		,@MobilePhoneAreaCode NVARCHAR(20)
		,@Fax NVARCHAR(50)
		,@FaxCountryCode NVARCHAR(20)
		,@FaxAreaCode NVARCHAR(20)
		,@Email NVARCHAR(254)
		,@Skype NVARCHAR(100)
		,@MSN NVARCHAR(100)
		,@Pic1 NVARCHAR(100)
		,@Pic2 NVARCHAR(100)
		,@Pic3 NVARCHAR(100)
		,@Pic4 NVARCHAR(100)
		,@Pic1Name NVARCHAR(200)
		,@Pic2Name NVARCHAR(200)
		,@Pic3Name NVARCHAR(200)
		,@Pic4Name NVARCHAR(200)
		,@Passport NVARCHAR(100)
		,@BettingCode NVARCHAR(50)
		,@RefCode2 NVARCHAR(50)
		,@IsVip BIT
		,@WhatsApp NVARCHAR(100)
		,@Line NVARCHAR(100)
		,@WeChat NVARCHAR(100)
		,@Yahoo NVARCHAR(100)
		,@QQ NVARCHAR(100)
		,@BBM NVARCHAR(100)
	DECLARE @CountryID INT
		,@SiteID INT
		,@LicenseeType INT
		,@RoleID INT = 7004
		,@tempUsername NVARCHAR(50)
		,@CommName NVARCHAR(MAX)
		,@tempRelatedCustIds VARCHAR(MAX)
		,@tempRelatedCustomers NVARCHAR(MAX)
		,@DefaultLanguage BiT = 0
	
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
	
	IF ISNULL(@CountryName,'') <> ''
	BEGIN
			SELECT @CountryID = CountryID
			FROM dbo.crmCountry WITH (NOLOCK)
			WHERE CountryName = @CountryName
	END
	
	IF @LanguageID =0
	BEGIN
		SET @DefaultLanguage =1
	END	

	
	UPDATE t
	SET t.FirstName = c.FirstName,
		t.LastName = c.LastName, 
		t.phone = c.phone,
		t.MobilePhone = c.MobilePhone,
		t.Fax = c.Fax,
		t.Email = c.Email,
		t.Birthday = c.Birthday,
		t.CountryID = CASE WHEN ISNULL(@CountryName,'') <> '' THEN @CountryID ELSE  ct.CountryID END,
		t.SiteID = (SELECT SettingID 
					FROM crmSetting WITH(NOLOCK) 
					WHERE SettingValue = ISNULL(c.site,ag.site)
						AND SettingName IN( 'Site','SiteCategory')
					)
	FROM #tblRelatedCustomer t
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON t.RelatedCustId = c.custid
		LEFT JOIN bodb02.dbo.Customer ag WITH(NOLOCK) ON c.recommend = ag.custid
		LEFT JOIN crmCountry ct ON c.country = ct.CountryName
	
	WHILE EXISTS (
			SELECT 1
			FROM @tmpUsername
			)
	BEGIN
		SELECT TOP 1 @CustID = CustId
			,@tempUsername = Username
		FROM @tmpUsername
		
		SELECT @ErrCode = 0
			,@ErrMsg = ''
			,@tempRelatedCustIds = ''
			,@tempRelatedCustomers = ''

		IF @IsCheckedDefaultComm = 1
		BEGIN
			SELECT @CommunicationID = STUFF((
						SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
						FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
						WHERE c.DefaultCommID = a.DefaultCommID
							AND c.SettingType = 3
						FOR XML path('')
						), 1, 1, '')
			FROM dbo.crmDefaultCommTool a WITH (NOLOCK)
			WHERE a.DefaultCommID <> 0
				AND a.CustID = @CustID
				AND STUFF((
						SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
						FROM dbo.[crmDefaultCommTool] c WITH (NOLOCK)
						WHERE c.DefaultCommID = a.DefaultCommID
							AND c.SettingType = 1
						ORDER BY c.SettingID ASC
						FOR XML path('')
						), 1, 1, '') = @Categorystr
				AND STUFF((
						SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
						FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
						WHERE c.DefaultCommID = a.DefaultCommID
							AND c.SettingType = 2
						ORDER BY c.SettingID ASC
						FOR XML path('')
						), 1, 1, '') = @SubCategorystr
		END

		IF ISNULL(@CommunicationID, '') = ''
			AND @IsCheckedDefaultComm = 1
		BEGIN
			SELECT @CommunicationID = STUFF((
						SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
						FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
						WHERE c.DefaultCommID = a.DefaultCommID
							AND c.SettingType = 3
						FOR XML path('')
						), 1, 1, '')
			FROM dbo.crmDefaultCommTool a WITH (NOLOCK)
			WHERE a.DefaultCommID <> 0
				AND a.CustID = @CustID
				AND STUFF((
						SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
						FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
						WHERE c.DefaultCommID = a.DefaultCommID
							AND c.SettingType = 1
						ORDER BY c.SettingID ASC
						FOR XML path('')
						), 1, 1, '') = @Categorystr
				AND EXISTS (
					SELECT TOP 1 1
					FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
					WHERE c.DefaultCommID = a.DefaultCommID
						AND c.SettingID = 0
						AND c.SettingType = 2
					)
		END

		IF ISNULL(@CommunicationID, '') = ''
			AND @IsCheckedDefaultComm = 1
		BEGIN
			SELECT @CommunicationID = STUFF((
						SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
						FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
						WHERE c.DefaultCommID = a.DefaultCommID
							AND c.SettingType = 3
						FOR XML path('')
						), 1, 1, '')
			FROM dbo.crmDefaultCommTool a WITH (NOLOCK)
			WHERE a.DefaultCommID <> 0
				AND a.CustID = @CustID
				AND EXISTS (
					SELECT TOP 1 1
					FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
					WHERE c.DefaultCommID = a.DefaultCommID
						AND c.SettingID = 0
						AND c.SettingType = 1
					)
				AND STUFF((
						SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
						FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
						WHERE c.DefaultCommID = a.DefaultCommID
							AND c.SettingType = 2
						ORDER BY c.SettingID ASC
						FOR XML path('')
						), 1, 1, '') = @SubCategorystr
		END

		IF ISNULL(@CommunicationID, '') = ''
			AND @IsCheckedDefaultComm = 1
		BEGIN
			SELECT @CommunicationID = STUFF((
						SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
						FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
						WHERE c.DefaultCommID = a.DefaultCommID
							AND c.SettingType = 3
						FOR XML path('')
						), 1, 1, '')
			FROM dbo.crmDefaultCommTool a WITH (NOLOCK)
			WHERE a.DefaultCommID <> 0
				AND a.CustID = @CustID
				AND EXISTS (
					SELECT TOP 1 1
					FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
					WHERE c.DefaultCommID = a.DefaultCommID
						AND c.SettingID = 0
						AND c.SettingType = 1
					)
				AND EXISTS (
					SELECT TOP 1 1
					FROM dbo.crmDefaultCommTool c WITH (NOLOCK)
					WHERE c.DefaultCommID = a.DefaultCommID
						AND c.SettingID = 0
						AND c.SettingType = 2
					)
		END

		IF ISNULL(@CommunicationID, '') = ''
			AND @IsCheckedDefaultComm = 1
		BEGIN
			SELECT @CommunicationID = 1005
		END

		IF ISNULL(@CommunicationID, '') <> ''
		BEGIN
			IF @IsCheckedDefaultComm = 1
			BEGIN
				INSERT INTO #tblComm (CommID)
				SELECT SettingID
				FROM dbo.strSplit(@CommunicationID, ',')

				SELECT @CommName = STUFF((
							SELECT '/' + s.SettingValue
							FROM #tblComm t
								INNER JOIN dbo.crmSetting s WITH (NOLOCK) ON t.CommID = s.SettingID
							FOR XML path('')
							), 1, 1, '')

				SELECT @AutoField = @AutoField1 + @AutoField2 + @CommName + @AutoField3
			END

			SELECT @tempRelatedCustomers = STUFF((
					SELECT ', ' + Username
					FROM #tblRelatedCustomer WITH (NOLOCK)
					WHERE CustId = @CustId
					FOR XML path('')
					), 1, 1, '')

			SELECT @tempRelatedCustIds = STUFF((
					SELECT ',' + CAST(RelatedCustId AS VARCHAR(20))
					FROM #tblRelatedCustomer WITH (NOLOCK)
					WHERE CustId = @CustId
					FOR XML path('')
					), 1, 1, '')

			IF @tempRelatedCustomers <> ''
			BEGIN
				IF CHARINDEX('System ID:', @AutoField) = 0
				BEGIN
					SET @AutoField = @AutoField + CHAR(13) + 'System ID:'
				END

				SET @AutoField = STUFF(@AutoField, CHARINDEX('System ID:', @AutoField), LEN('System ID:'), 'System ID: ' + @tempRelatedCustomers)
			END

			IF NOT EXISTS (
					SELECT 1
					FROM dbo.crmCustomer WITH (NOLOCK)
					WHERE CustID = @CustID
					)
			BEGIN
				---- insert new customer
				EXECUTE dbo.Acc_CRM_CustomerIns_New @UserID = @UserID
					,@CustID = @CustID
					,@UserName = @tempUsername
					,@FirstName = @FirstName
					,@LastName = @LastName
					,@TitleID = @TitleID
					,@Birthday = @Birthday
					,@LanguageID = @LanguageID
					,@Phone = @Phone
					,@PhoneCountryCode = @PhoneCountryCode
					,@PhoneAreaCode = @PhoneAreaCode
					,@Phone2 = @Phone2
					,@Phone2CountryCode = @Phone2CountryCode
					,@Phone2AreaCode = @Phone2AreaCode
					,@Phone3 = @Phone3
					,@Phone3CountryCode = @Phone3CountryCode
					,@Phone3AreaCode = @Phone3AreaCode
					,@MobilePhone = @MobilePhone
					,@MobilePhoneCountryCode = @MobilePhoneCountryCode
					,@MobilePhoneAreaCode = @MobilePhoneAreaCode
					,@Fax = @Fax
					,@FaxCountryCode = @FaxCountryCode
					,@FaxAreaCode = @FaxAreaCode
					,@Email = @Email
					,@Passport = @Passport
					,@BettingCode = @BettingCode
					,@RefCode2 = @RefCode2
					,@Skype = @Skype
					,@MSN = @MSN
					,@CountryID = @CountryID
					,@IsVIP = 0
					,@SiteID = NULL
					,@CreatorID = @CreatorID
					,@LicenseeType = NULL
					,@WhatsApp = @WhatsApp
					,@Line = @Line
					,@WeChat = @WeChat
					,@Yahoo = @Yahoo
					,@QQ = @QQ
					,@BBM = @BBM
					,@IP = @IP
					,@Pic1 = @Pic1
					,@Pic2 = @Pic2
					,@Pic3 = @Pic3
					,@Pic4 = @Pic4
					,@ProvinceID = NULL					
					,@ErrCode = @ErrCode OUTPUT
					,@ErrMsg = @ErrMsg OUTPUT;

				IF @ErrCode <> 0
				BEGIN
					SELECT @ErrCode = 101,
						@ErrMsg = 'Insert failed'

					RETURN;
				END;
			END;
			
			IF @AmendmentLogID > 0
			BEGIN
				EXECUTE	dbo.Acc_CRM_AmendmentNoti_MultiCustIns
					@RelatedCustomers = @RelatedCustomers
					,	@UserID					= @UserID
					,   @CreatorID				= @CreatorID
					,	@IP						= @IP
					,	@ErrCode				= @ErrCode OUTPUT
					,	@ErrMsg					= @ErrMsg OUTPUT;
				IF @ErrCode <> 0
				BEGIN
					--SELECT @ErrCode 
					RETURN;
				END;
			END
			ELSE
			BEGIN
				--Sync profile for related customers to CRM
				WHILE (1=1)
				BEGIN 
					UPDATE TOP (1) t
					SET isFinished = 1,
						@r_Custid = RelatedCustID,
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
					FROM #tblRelatedCustomer t
					WHERE isFinished = 0
						AND custid = @custid		
						AND NOT EXISTS (SELECT 1
										FROM dbo.crmCustomer c WITH (NOLOCK)
										WHERE c.CustID = t.RelatedCustID)
						
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
					,	@LanguageID				= @LanguageID
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
		
			--- create account for guest		
			SELECT @CustID = c.CustID
				,@TitleID = c.TitleID
				,@FirstName = c.FirstName
				,@LastName = c.LastName
				,@Birthday = c.Birthday
				,@Phone = c.Phone
				,@PhoneCountryCode = c.PhoneCountryCode
				,@PhoneAreaCode = c.PhoneAreaCode
				,@Phone2 = c.Phone2
				,@Phone2CountryCode = c.Phone2CountryCode
				,@Phone2AreaCode = c.Phone2AreaCode
				,@Phone3 = c.Phone3
				,@Phone3CountryCode = c.Phone3CountryCode
				,@Phone3AreaCode = c.Phone3AreaCode
				,@MobilePhone = c.MobilePhone
				,@MobilePhoneCountryCode = c.MobilePhoneCountryCode
				,@MobilePhoneAreaCode = c.MobilePhoneAreaCode
				,@Fax = c.Fax
				,@FaxCountryCode = c.FaxCountryCode
				,@FaxAreaCode = c.FaxAreaCode
				,@Email = c.Email
				,@Skype = c.Skype
				,@MSN = c.MSN
				,@Pic1 = c.Pic1
				,@Pic2 = c.Pic2
				,@Pic3 = c.Pic3
				,@Pic4 = c.Pic4
				,@Pic1Name = c.Pic1Name
				,@Pic2Name = c.Pic2Name
				,@Pic3Name = c.Pic3Name
				,@Pic4Name = c.Pic4Name
				,@Passport = c.Passport
				,@BettingCode = c.RefCode1
				,@RefCode2 = c.RefCode2
				,@IsVip = c.IsVip
				,@WhatsApp = c.WhatsApp
				,@Line = c.Line
				,@WeChat = c.WeChat
				,@Yahoo = c.Yahoo
				,@QQ = c.QQ
				,@BBM = BBM
				,@CountryID = CASE WHEN ISNULL(@CountryName,'') <> '' THEN @CountryID  ELSE CountryID END
				,@SiteID = SiteID
				,@LicenseeType = LicenseeType
			FROM dbo.crmCustomer c WITH (NOLOCK)
			WHERE c.CustID = @CustID

			SELECT @RoleID = CASE 
					WHEN c.roleid = 1 THEN 7000
					WHEN c.roleid = 2 THEN 7001
					WHEN c.roleid = 3 THEN 7002
					WHEN c.roleid = 4 THEN 7003
					ELSE 7004
					END
			FROM bodb02.dbo.Customer c WITH (NOLOCK)
			WHERE c.CustID = @CustID
			
			IF @DefaultLanguage = 1
			BEGIN
				SELECT @LanguageID = LanguageID
				FROM dbo.crmCustomerLanguage WITH (NOLOCK)
				WHERE Custid = @CustID
			END	

			--- insert feedback of guest 
			EXECUTE dbo.Acc_CRM_FeedbackIns @UserID = @UserID
				,@CustID = @CustID
				,@UserName = @tempUsername
				,@TitleID = @TitleID
				,@Birthday = @Birthday
				,@FirstName = @FirstName
				,@LastName = @LastName
				,@Phone = @Phone
				,@PhoneCountryCode = @PhoneCountryCode
				,@PhoneAreaCode = @PhoneAreaCode
				,@Phone2 = @Phone2
				,@Phone2CountryCode = @Phone2CountryCode
				,@Phone2AreaCode = @Phone2AreaCode
				,@Phone3 = @Phone3
				,@Phone3CountryCode = @Phone3CountryCode
				,@Phone3AreaCode = @Phone3AreaCode
				,@MobilePhone = @MobilePhone
				,@MobilePhoneCountryCode = @MobilePhoneCountryCode
				,@MobilePhoneAreaCode = @MobilePhoneAreaCode
				,@Fax = @Fax
				,@FaxCountryCode = @FaxCountryCode
				,@FaxAreaCode = @FaxAreaCode
				,@Email = @Email
				,@Skype = @Skype
				,@MSN = @MSN
				,@CountryID = @CountryID
				,@Pic1 = @Pic1
				,@Pic2 = @Pic2
				,@Pic3 = @Pic3
				,@Pic4 = @Pic4
				,@Pic1Name = @Pic1Name
				,@Pic2Name = @Pic2Name
				,@Pic3Name = @Pic3Name
				,@Pic4Name = @Pic4Name
				,@Passport = @Passport
				,@BettingCode = @BettingCode
				,@RefCode2 = @RefCode2
				,@IsVip = 0
				,@SiteID = @SiteID
				,@LanguageID = @LanguageID
				,@CreatorID = @CreatorID
				,@Subject = @Subject
				,@FeedbackDate = @FeedbackDate
				,@ResolutionDate = @ResolutionDate
				,@CommunicationID = @CommunicationID
				,@StationID = @StationID
				,@Category = @Category
				,@Product = @Product
				,@RoleID = @RoleID
				,@ResponseID = @ResponseID
				,@StatusID = @StatusID
				,@RelatedCustID = @tempRelatedCustIds
				,@Description = @Description
				,@AutoField = @AutoField
				,@Solution = @Solution
				,@IsReviewed = @IsReviewed
				,@Review = @Review
				,@ReviewerID = @ReviewerID
				,@LicenseeType = @LicenseeType
				,@WhatsApp = @WhatsApp
				,@Line = @Line
				,@WeChat = @WeChat
				,@Yahoo = @Yahoo
				,@QQ = @QQ
				,@BBM = @BBM
				,@IP = @IP
				,@NoInquiries = @NoInquiries
				,@MessageID = @MessageID
				,@WinLimitLogID = @WinLimitLogID
				,@TOControlLogID = @TOControlLogID	
				,@PALogID = @PALogID	
				,@AmendmentLogID = @AmendmentLogID
				,@RequestIDs = @RequestIDs
				,@ListOrigCustIDs = @ListOrigCustIDs
				,@IsManualMultiple = @IsManualMultiple
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT;

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrMsg = CASE WHEN @ErrCode = 110 AND @IsManualMultiple = 1
										THEN @ErrMsg ELSE 'Insert failed 2' END
					,@ErrCode = 102

				RETURN;
			END
		END

		DELETE
		FROM @tmpUsername
		WHERE CustId = @CustID
		
		IF @DefaultLanguage = 1
		BEGIN
			SET @LanguageID = 0
		END
		
		IF @IsCheckedDefaultComm = 1
		BEGIN
			TRUNCATE TABLE #tblComm

			SELECT @CommunicationID = ''
		END
	END

	DROP TABLE #tblComm
	DROP TABLE #tblRelatedCustomer
END
