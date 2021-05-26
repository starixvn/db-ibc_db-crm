/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_RelatedCustomerVerify
(
	@UserName	NVARCHAR(MAX) = '',
	@UserRole   TINYINT
)
AS
/*
	Created: Lukas
	Date: 20110629
	Task : verify list of related customer
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20120131@Lukas: verify guest user
		- 20120405@Elodie: return 2 CustID if username is real customer as well as guest
		- 20120409@Elodie: return username and custid = 0 if customer doesn't exist
		- 20121115@Lukas: change the query to use index on DB06
		- 20130121@Johnson: change linked server DB06 to DBACC
		- 20180305@Winnie: Support long list of "Verify related customer" RedmineID: #91469
		- 20190506@Winnie:  CN88 Permission - [RedmineID: #112637]
		- 20190701@Elodie: Offer for CN88 - [RedmineID: #112637]
		- 20190905@Winnie: CRM - Left panel did not show Super, Master, Agent  [RedmineId: #119708]
		- 20210528@Johnson: get site status for list related customers [Redmine: #154840]
	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpCustomer TABLE(UserName VARCHAR(50))
	DECLARE @Customer TABLE(CustID INT, UserName VARCHAR(50), siteID INT, IsSiteActive BIT)

	INSERT INTO @tmpCustomer(UserName)
	SELECT ltrim(rtrim(val)) UserName
	FROM dbo.f_CRM_strSplit(@UserName,',')		
		
	INSERT INTO @Customer(CustID, UserName, SiteID, isSiteActive)
	SELECT c.custid, c.username, siteID, s.isActive
	FROM bodb02.dbo.Customer c WITH (NOLOCK)
		INNER JOIN crmCustomer cm WITH(NOLOCK) ON c.custid = cm.custid
		LEFT JOIN crmSetting s WITH(NOLOCK) ON cm.siteID = s.SettingID 
	WHERE c.username IN ( SELECT username FROM @tmpCustomer)
		AND ((@UserRole=1 AND c.site = 'CN88') OR (@UserRole=2 AND ISNULL(c.site,'') <> 'CN88'))
	
	INSERT INTO @Customer(CustID, UserName, SiteID, IsSiteActive)
	SELECT c.custid, c.username, c.SiteID, s.IsActive 
	FROM crmCustomer c WITH (NOLOCK) 
		INNER JOIN @tmpCustomer tc on c.username = tc.UserName
		LEFT JOIN crmSetting s WITH(NOLOCK) ON cm.siteID = s.SettingID 
	WHERE c.CustID < 0	
		AND ((@UserRole=1 AND c.SiteID = 33002) OR (@UserRole=2 AND c.SiteID <> 33002))

	INSERT INTO @Customer(CustID, UserName)
	SELECT 0, tc.username 
	FROM @tmpCustomer tc 
	WHERE tc.UserName NOT IN (SELECT UserName FROM @Customer)

	SELECT CustID, UserName as val, ISNULL(SiteID,0) SiteID, ISNULL(IsSiteActive,0) as IsSiteActive
	FROM @Customer
	ORDER BY UserName 
END
GO
