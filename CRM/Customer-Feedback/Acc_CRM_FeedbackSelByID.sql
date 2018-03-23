/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackSelByID] (
					@FeedbackID INT
				)
AS
/*
	Created:	Lukas
	Date:		20101023
	Task:		get feedback info
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas:	support get multipe related customer
		- 20120307@Elodie:	get more 3 values Pic1, Pic2, Pic3
		- 20120319@Elodie:	change DB06 to DB052
		- 20140303@Dom:		Modify for new structure
		- 20141118@Dom:		get more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20160531@Winnie:  Add more cust info
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
	Param's Explanation:
		
*/
BEGIN	
	SET NOCOUNT ON;

	DECLARE	@RelatedCustID	 INT
		,	@RelatedUserName NVARCHAR(MAX)
		,   @AutoField       NVARCHAR(MAX)
		,   @Remark		     NVARCHAR(MAX)
		,	@xmlDoc			 XML
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

		
	--- get feedback info
	SELECT	fb.FeedbackID
		,	fb.CustID
		,	ctm.UserName
		,	ISNULL(fb.TitleID, 0) TitleID
		,	fb.FirstName
		,	fb.LastName
		,	fb.Birthday
		,	fb.Phone
		,	fb.PhoneAreaCode
		,	fb.PhoneCountryCode
		,	fb.Phone2
		,	fb.Phone2AreaCode
		,	fb.Phone2CountryCode
		,	fb.Phone3
		,	fb.Phone3AreaCode
		,	fb.Phone3CountryCode
		,	fb.MobilePhone
		,	fb.MobilePhoneAreaCode
		,	fb.MobilePhoneCountryCode
		,	fb.Fax
		,	fb.FaxAreaCode
		,	fb.FaxCountryCode
		,	fb.Passport
		,	fb.RefCode1
		,	fb.RefCode2
		,	ISNULL(fb.IsVip, 0) IsVip
		,	fb.Email
		,	fb.Skype
		,	fb.MSN
		,	ISNULL(fb.LanguageID, 0) LanguageID
		,	ISNULL(fb.CountryID, 0) CountryID
		,	fb.CreatorID
		,	c.username AS CreatorName
		,	fb.FeedbackDate
		,	fb.ResolutionDate
		,	fb.CreateDate
		,	fb.SolveDate
		,	fb.LanguageID
		,	ISNULL(fb.CommunicationID, 0) CommunicationID
		,	ISNULL(fb.StationID, 0) StationID
		,	ISNULL(fb.MainCategoryID, 0) MainCategoryID
		,	ISNULL(fb.SubCategoryID, 0) SubCategoryID
		,	ISNULL(fb.SiteID, 0) SiteID
		,	ISNULL(fb.RoleID, 0) RoleID
		,	ISNULL(fb.ProductID, 0) ProductID
		,	ISNULL(fb.SubProductID, 0) SubProductID
		,	ISNULL(fb.BetTypeID, 0) BettypeID
		,	ISNULL(fb.ResponseID, 0) ResponseID
		,	ISNULL(fb.StatusID, 0) StatusID
		,	@AutoField AS AutoField
		,	@Remark AS Description
		,	fb.Solution
		,	fb.IsReviewed
		,	fb.Review
		,	ISNULL(fb.ReviewerID, 0) ReviewerID
		,	rv.username AS ReviewerName
		,	fb.Subject		
		,	ISNULL(fb.Pic1, '') Pic1
		,	ISNULL(fb.Pic2, '') Pic2
		,	ISNULL(fb.Pic3, '') Pic3
		,	ISNULL(fb.Pic4, '') Pic4
		,	ISNULL(fb.Pic1Name, '') Pic1Name
		,	ISNULL(fb.Pic2Name, '') Pic2Name
		,	ISNULL(fb.Pic3Name, '') Pic3Name
		,	ISNULL(fb.Pic4Name, '') Pic4Name
		,	ISNULL(fb.WhatsApp, '') WhatsApp
		,	ISNULL(fb.Line, '') Line
		,	ISNULL(fb.WeChat, '') WeChat
		,	ISNULL(fb.Yahoo, '') Yahoo
		,	ISNULL(fb.QQ, '') QQ
		,	ISNULL(fb.BBM, '') BBM
		,	fb.LicenseeType
	FROM	crmFeedback fb WITH (NOLOCK)	
	INNER JOIN	crmCustomer ctm WITH (NOLOCK)
			ON	fb.CustID = ctm.CustID
	INNER JOIN bodb02.dbo.custInfo c WITH (NOLOCK)
			ON	fb.CreatorID = c.custid
	LEFT JOIN bodb02.dbo.custInfo rv WITH (NOLOCK)
			ON	fb.ReviewerID = rv.custid
	WHERE	fb.FeedbackID = @FeedbackID;	
	
		SELECT	cf.CustID
		,	ISNULL(c.UserName, c1.username ) UserName
	FROM		dbo.crmFeedbackCustomer AS cf WITH (NOLOCK)
	LEFT JOIN	dbo.crmCustomer AS c WITH (NOLOCK)
			ON	c.CustID = cf.CustID
	LEFT JOIN	bodb02.dbo.Customer AS c1 WITH (NOLOCK)
			ON	c1.custid = cf.CustID
	WHERE	cf.FeedbackID = @FeedbackID 
		AND	cf.IsRelated = 1;
END;

GO

GRANT EXECUTE ON dbo.Acc_CRM_FeedbackSelByID TO bodbAdminNet;
GO 
GRANT VIEW DEFINITION ON dbo.Acc_CRM_FeedbackSelByID TO vnteam;
GO 
