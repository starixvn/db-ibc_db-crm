/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
	FROM		dbo.crmFeedback AS f WITH (NOLOCK)
		LEFT JOIN	dbo.crmCustomer AS c WITH (NOLOCK)
			ON	c.CustID = f.CustID
		LEFT JOIN	bodb02.dbo.Customer AS review WITH (NOLOCK)
			ON	f.ReviewerID = review.custid
	WHERE	f.FeedbackID = @FeedbackID
		AND((@UserRole=1 AND c.SiteID=33002) OR (@UserRole=2 AND c.SiteID<>33002))

	SELECT	cf.CustID
		,	ISNULL(c.UserName, c1.username ) UserName
	FROM		dbo.crmFeedbackCustomer AS cf WITH (NOLOCK)
		LEFT JOIN	dbo.crmCustomer AS c WITH (NOLOCK)
			ON	c.CustID = cf.CustID
		LEFT JOIN	bodb02.dbo.Customer AS c1 WITH (NOLOCK)
			ON	c1.custid = cf.CustID
	WHERE	cf.FeedbackID = @FeedbackID 
		AND((@UserRole=1 AND c.SiteID=33002) OR (@UserRole=2 AND c.SiteID<>33002))
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

