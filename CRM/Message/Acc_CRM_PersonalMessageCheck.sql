/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PersonalMessageCheck]
	@UserName	VARCHAR(MAX),		--max 50 users
	@ErrCode	INT	= 0				OUTPUT,
	@ErrMsg		NVARCHAR(200) = ''	OUTPUT
AS
/*
	Created: 20230308@Tacy
    Task: CRM - Sending Personal Message to SMA in Alpha site
    DB: DBCUST-CustDB
	Original:

	Revisions:
		- 20230308@Tacy: Create SP
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tbUser (UserName VARCHAR(30))

	IF @UserName <>'' OR @UserName IS NOT NULL
	BEGIN
		INSERT INTO #tbUser (UserName)
		SELECT RTRIM(LTRIM(value))
		FROM string_split(@UserName,',')
	END
	
	--Check: exists Username
	IF EXISTS (SELECT 1 
				FROM #tbUser t
				WHERE NOT EXISTS (SELECT 1 FROM Customer c WITH (NOLOCK)
								  WHERE c.username=T.UserName))
	BEGIN
		SET @ErrCode=100
		SET @ErrMsg='Invalid username(s): ' 
					+ STUFF ((SELECT ', ' + t.UserName
							  FROM #tbUser t
							  WHERE NOT EXISTS (SELECT 1 FROM Customer c WITH (NOLOCK)
												WHERE c.username=T.UserName)
							  FOR XML PATH('')),1,1,'')
		RETURN
	END
	ELSE IF	--check: support credit user only
		EXISTS (SELECT 1 
				FROM #tbUser t  
				INNER JOIN Customer c WITH (NOLOCK) ON c.username=T.UserName
				INNER JOIN Dep_CustSuper cs WITH (NOLOCK) ON cs.custid=c.srecommend)
	BEGIN
		SET @ErrCode=101
		SET @ErrMsg='Invalid username(s): ' 
					+ STUFF ((SELECT ', ' + t.UserName
							  FROM #tbUser t  
							  INNER JOIN Customer c WITH (NOLOCK) ON c.username=T.UserName
							  INNER JOIN Dep_CustSuper cs WITH (NOLOCK) ON cs.custid=c.srecommend
							  FOR XML PATH('')),1,1,'')
		RETURN
	END
	ELSE IF	--check: not allow member level
		EXISTS (SELECT 1 
				FROM #tbUser t
				INNER JOIN Customer c WITH (NOLOCK) ON c.username=T.UserName
				WHERE c.roleid NOT IN (2,3,4))
	BEGIN
		SET @ErrCode=102
		SET @ErrMsg='Invalid username(s): ' 
					+ STUFF ((SELECT ', ' + t.UserName
							  FROM #tbUser t
							  INNER JOIN Customer c WITH (NOLOCK) ON c.username=T.UserName
							  WHERE c.roleid NOT IN (2,3,4)
							  FOR XML PATH('')),1,1,'')
		RETURN
	END
END