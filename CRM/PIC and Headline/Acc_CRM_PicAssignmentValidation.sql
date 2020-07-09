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
	
	DECLARE @GroupID INT, @InvalidUsername VARCHAR(MAX) = NULL, @NotDirectAccount VARCHAR(MAX) = NULL, @NoBelongHeadlineAccount VARCHAR(MAX) = NULL

	DECLARE @tblUsername TABLE (Username VARCHAR(MAX), CustId INT, srecommend INT, recommend INT,RoleId INT,IsDirectAccount BIT, IsBelongHeadline BIT)

	SELECT @GroupID = GroupID FROM bodb02.dbo.CustGroupHeadline WITH(NOLOCK) WHERE custid = @HeadlineID

	IF @GroupID IS NULL
		SELECT @GroupID = 0

	INSERT INTO @tblUsername (Username)
	SELECT DISTINCT val FROM dbo.f_split(@UserName, ',')

	UPDATE t
	SET t.CustId = c.custid, t.srecommend = c.srecommend, t.RoleId = c.roleid, t.recommend = c.recommend
	FROM @tblUsername t
		INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON t.Username = c.username

	-- check  usernames
	IF EXISTS (SELECT 1 FROM @tblUsername WHERE CustId IS NULL)
	BEGIN
		SELECT @InvalidUsername = STUFF((SELECT ',' + Username 
											FROM @tblUsername
											WHERE CustId IS NULL
											FOR XML PATH('')),1,1,'')	
		DELETE @tblUsername
		WHERE custid IS NULL

		SELECT @ErrCode = 1007
	END

	-- check direct accounts
	IF EXISTS (SELECT 1 FROM @tblUsername)
	BEGIN
		UPDATE t
		SET t.IsDirectAccount = 1
		FROM @tblUsername t
			INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON t.CustId = cda.CustID	
		
		UPDATE t
		SET t.IsDirectAccount = NULL
		FROM @tblUsername t
		WHERE EXISTS(SELECT 1 FROM bodb02.dbo.CustSuper  s WITH(NOLOCK) WHERE t.CustId = s.custid AND s.IsInternal = 1)
			AND t.RoleId = 4

		UPDATE t
		SET t.IsDirectAccount = NULL
		FROM @tblUsername t
		WHERE EXISTS(SELECT 1 FROM bodb02.dbo.CustMaster  m WITH(NOLOCK) WHERE t.CustId = m.custid AND m.IsInternal = 1)
			AND t.RoleId = 4

		UPDATE t
		SET t.IsDirectAccount = NULL
		FROM @tblUsername t
		WHERE EXISTS(SELECT 1 FROM bodb02.dbo.CustAgent  ag WITH(NOLOCK) WHERE  t.recommend = ag.custid AND ag.IsInternal = 1)
			AND t.RoleId IN (1,2)

	END
	
	IF EXISTS (SELECT 1 FROM @tblUsername WHERE IsDirectAccount IS NULL)
	BEGIN	 
		SELECT @NotDirectAccount =  STUFF((SELECT ',' + Username
											FROM @tblUsername
											WHERE IsDirectAccount IS NULL
											FOR XML PATH('')),1,1,'')
		DELETE @tblUsername
		WHERE IsDirectAccount IS NULL

		SELECT @ErrCode = 1007
	END

	-- check direct accounts are belonging to the headline 
	IF EXISTS (SELECT 1 FROM @tblUsername)
	BEGIN
		UPDATE t
		SET t.IsBelongHeadline = 1
		FROM @tblUsername t	
			LEFT JOIN bodb02.dbo.custAccount ca WITH (NOLOCK) ON t.CustId = ca.CustID AND ca.groupID <> 0
		WHERE ISNULL(ca.groupID,0) = @GroupID
	END

	IF EXISTS (SELECT 1 FROM @tblUsername WHERE IsBelongHeadline IS NULL)
	BEGIN	 
		SELECT @NoBelongHeadlineAccount =  STUFF((SELECT ',' + Username
													FROM @tblUsername
													WHERE IsBelongHeadline IS NULL
													FOR XML PATH('')),1,1,'')
		DELETE @tblUsername
		WHERE IsDirectAccount IS NULL

		SELECT @ErrCode = 1007
	END

	-- Return data
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
			INNER JOIN @tblUsername t ON t.CustID = m.CustID
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
END