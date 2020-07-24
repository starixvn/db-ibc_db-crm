/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicAssignmentValidation]
	@UserName       VARCHAR(MAX)
AS
/*
Created: 20200511@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200511@Malcolm: CRM - Staff/Boss Management of headline [Redmine: #108739]
		- 20200803@Malcolm: CRM - Integrate Credit Term & Staff/Boss Management [Redmine: #137144]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON
	
	DECLARE @tblUsername TABLE (Username VARCHAR(MAX), CustId INT)

	INSERT INTO @tblUsername (Username)
	SELECT DISTINCT val FROM dbo.f_split(@UserName, ',')

	UPDATE t
	SET t.CustId = c.custid
	FROM @tblUsername t
		INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON t.Username = c.username

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