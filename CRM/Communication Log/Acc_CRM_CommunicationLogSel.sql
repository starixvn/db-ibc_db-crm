/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE	dbo.Acc_CRM_CommunicationLogSel
					@FeedbackID			INT
					,@UserRole			TINYINT
AS
/*
	Created:	Dom
	Date:		20140120
	Task:		Select Communication Log detail
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20141118@Dom:		add more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20190905@Winnie: CRM - Left panel did not show Super, Master, Agent  [RedmineId: #119708]  
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
		- 20191106@Winnie: Enhancement - Support "0" value on "No. of Inquiry" RedmineID: #123426
		- 20210601@Johnson: Prevent CSD create new feedback mistakenly If the licensee is terminated [redmine:#154840]
        - 20240509@Ned.Le: CRM - Can NOT searching for guest account with username is Thai language on Leftpanel and show related customer of an archive account is NOT being resused is Unauthorized Access on Feedback (HotFix #210353)
*/
BEGIN
	DECLARE   @AutoField       NVARCHAR(MAX)
			, @Remark		   NVARCHAR(MAX)
			, @xmlDoc		   XML
	DECLARE @iDoc AS INT
	SELECT @xmlDoc=CAST(Description AS XML)
	FROM crmfeedback WITH(NOLOCK) WHERE FeedbackID = @FeedbackID

	EXECUTE	sp_xml_preparedocument @iDoc OUTPUT, @xmlDoc;

	SELECT	@AutoField=ox.AutoField,@Remark=ox.Remark
	FROM OPENXML (@iDoc, '/ROOT/row', 1) 
	WITH (
		AutoField		NVARCHAR(MAX)
	,	Remark			NVARCHAR(MAX)	
	) AS ox;


	SELECT	f.FeedbackID
		,	f.CustID
		,	c.UserName
		,	f.FeedbackDate
		,	f.ResolutionDate	
		,	f.StatusID
		,	f.RoleID	
		,	f.CountryID
		,	f.LanguageID	
		,	f.SiteID
		,	f.ResponseID
		,	f.Subject
		,	@AutoField	AS AutoField
		,	@Remark		AS Description
		,	f.Solution
		,	f.IsReviewed
		,	f.Review
		,	review.username reviewer
		,	f.SolveDate
		,	f.LicenseeType
		,	CASE WHEN @UserRole=1 AND f.ProvinceID IS NULL THEN 1 ELSE f.ProvinceID END AS ProvinceID
		,   ISNULL(f.Inquiries,0) AS NoInquiries
		,	CASE WHEN sr.SettingID IS NOT NULL THEN 1 ELSE 0 END AS IsLicensee
		,	ISNULL(s.IsActive,0) as IsSiteActive
	FROM		dbo.crmFeedback AS f WITH (NOLOCK)
		LEFT JOIN	dbo.crmCustomer AS c WITH (NOLOCK)
			ON	c.CustID = f.CustID
		LEFT JOIN	bodb02.dbo.Customer AS review WITH (NOLOCK)
			ON	f.ReviewerID = review.custid
		LEFT JOIN crmSetting s WITH(NOLOCK) ON c.SiteID = s.SettingID		
		LEFT JOIN crmSettingRelation sr WITH(NOLOCK) ON s.SettingID = sr.SettingID
														AND sr.ParentID = 33000--licensee
	WHERE	f.FeedbackID = @FeedbackID
		AND((@UserRole=1 AND c.SiteID=33002) OR (@UserRole=2 AND ISNULL(c.SiteID,0)<>33002))

	SELECT	CASE WHEN cf.CustID > 0 AND c1.custid IS NULL THEN 0 ELSE cf.CustID END CustID
		,	ISNULL(c.UserName, c1.username ) UserName
		,	CASE WHEN sr.SettingID IS NOT NULL THEN 1 ELSE 0 END AS IsLicensee
		,	ISNULL(s.IsActive,0) as IsSiteActive
	FROM		dbo.crmFeedbackCustomer AS cf WITH (NOLOCK)
		LEFT JOIN	dbo.crmCustomer AS c WITH (NOLOCK)
			ON	c.CustID = cf.CustID
		LEFT JOIN	bodb02.dbo.Customer AS c1 WITH (NOLOCK)
			ON	c1.custid = cf.CustID
		LEFT JOIN crmSetting s WITH(NOLOCK) ON (c.SiteID = s.SettingID AND c.CustID IS NOT NULL)
											OR (c1.site = s.SettingValue AND s.SettingName = 'Site' AND c.custid IS NULL)		
		LEFT JOIN crmSettingRelation sr WITH(NOLOCK) ON s.SettingID = sr.SettingID
														AND sr.ParentID = 33000--licensee									
	WHERE	cf.FeedbackID = @FeedbackID 	
		AND	cf.IsRelated = 1;
		
	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
		CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
				WHEN s.StationID		IS NOT NULL THEN 'Station' 
				WHEN p.SettingID		IS NOT NULL THEN 'Product' 
				WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
				END AS SettingType
		FROM dbo.f_GetFeedbackSetting(@FeedbackID,0,0,3) fs
			LEFT JOIN crmMainCategory m 
				ON fs.SettingID=m.MainCategoryID
			LEFT JOIN crmStation s 
				ON fs.SettingID=s.StationID
			LEFT JOIN crmSetting p
				ON fs.SettingID=p.SettingID AND p.SettingName='Product'
			LEFT JOIN crmSetting c
				ON fs.SettingID=c.SettingID AND c.SettingName='Communication'
	
END;
GO

