/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicAssignmentValidation]
    @HeadlineID	    INT,
	@PicID			NVARCHAR(MAX),
	@UserName       VARCHAR(MAX),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20200511@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200511@Malcolm: CRM - Staff/Boss Management of headline [Redmine: #108739]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON
	
	DECLARE @GroupID INT = 0,@InvalidUsername VARCHAR(MAX) = NULL, @NotDirectAccount VARCHAR(MAX) = NULL, @NoBelongHeadlineAccount VARCHAR(MAX) = NULL

	CREATE TABLE #Tmp (Username VARCHAR(30), CustID INT,IsCustomer BIT, IsDirectAccount BIT,IsHeadlineGroup BIT)

	SELECT @GroupID = GroupID FROM bodb02.dbo.CustGroupHeadline WITH(NOLOCK) WHERE custid = @HeadlineID

	INSERT INTO #Tmp
	(
		Username
	)
	SELECT DISTINCT Val
	FROM bodb02.dbo.strSplit(@UserName,',')

	UPDATE t
	SET IsCustomer		=	CASE WHEN c.custid IS NULL THEN 0 
							ELSE 1 END,

		IsDirectAccount =	CASE WHEN ca.custid IS NULL	THEN 0
							     WHEN ISNULL(s.IsInternal,0) = 1 THEN 0
							ELSE 1 END,

		IsHeadlineGroup =   CASE WHEN ISNULL(u.groupID, 0) = @GroupID THEN 1
							ELSE 0 END, 

		CustID          =	c.custid
	FROM #Tmp AS t
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.username = t.Username
		LEFT JOIN bodb02.dbo.CustDirectAccount ca WITH(NOLOCK) ON ca.CustID = c.custid
		LEFT JOIN bodb02.dbo.custAccount u WITH(NOLOCK) ON c.custid = u.custid 
		LEFT JOIN bodb02.dbo.CustSuper s WITH(NOLOCK) ON s.custid = c.srecommend

	-- check  usernames
	IF EXISTS (SELECT 1 FROM #Tmp WHERE IsCustomer = 0)
	BEGIN
		SELECT @InvalidUsername = STUFF((SELECT ',' + Username 
													   FROM #Tmp
													   WHERE IsCustomer = 0
													   FOR XML PATH('')),1,1,'')	
		DELETE #Tmp
		WHERE IsCustomer = 0

		SELECT @ErrCode = 1007
	END

	-- check direct accounts
	IF EXISTS (SELECT 1 FROM #Tmp WHERE IsDirectAccount = 0)
	BEGIN	 
		SELECT @NotDirectAccount =  STUFF((SELECT ',' + Username
									  FROM #Tmp
									  WHERE IsDirectAccount = 0
							          FOR XML PATH('')),1,1,'')
		DELETE #Tmp
		WHERE IsDirectAccount = 0

		SELECT @ErrCode = 1007
	END
	-- check direct accounts are belonging to the headline 
	IF EXISTS (SELECT 1 FROM #Tmp WHERE IsHeadlineGroup = 0)
	BEGIN
		SELECT @NoBelongHeadlineAccount = STUFF((SELECT ',' + Username 
										   FROM #Tmp
										   WHERE IsHeadlineGroup = 0
										   FOR XML PATH('')),1,1,'')
		DELETE #Tmp
		WHERE IsHeadlineGroup = 0

		SELECT @ErrCode = 1007		
	END

	IF @ErrCode = 1007
	BEGIN
		SELECT @InvalidUsername AS InvalidUsername, @NotDirectAccount AS NotDirectAccount, @NoBelongHeadlineAccount AS NoBelongHeadlineAccount

		SELECT NULL AS PicName, NULL AS Role, NULL AS DirectAccount
		WHERE 1 = 0

		RETURN
	END

	SELECT NULL AS InvalidUsername, NULL AS NotDirectAccount, NULL AS NoBelongHeadlineAccount
	WHERE 1 = 0

	;WITH CTE AS (
		SELECT t.Username AS Username, p.Username AS PicName, s.SettingValue AS [Role]
		FROM dbo.crmPicManagement m WITH(NOLOCK) 
			INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = m.PicID 
			INNER JOIN #Tmp t ON t.CustID = m.CustID
			LEFT JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role 
	)
	SELECT 
		t.PicName AS PicName,
		t.Role,
		STUFF ((SELECT ', ' + e.Username 
				FROM CTE e 
				WHERE e.PicName = t.PicName
				FOR XML PATH('')),1,1,'') AS DirectAccount
	FROM CTE t 
	GROUP BY t.PicName, t.Role
	
	DROP TABLE #Tmp
END