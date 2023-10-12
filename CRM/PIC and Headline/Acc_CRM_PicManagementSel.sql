/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_PicManagementSel]
	@Username		VARCHAR(30) = '',
	@Role			VARCHAR(100) = '',
	@HeadlineName	VARCHAR(30) = '',
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT
AS

/*
Created: 20200506@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: CRM - Staff/Boss Management of headline [Redmine: #108739]
		- 20200814@Malcolm: Sort Ouput by IsActive ,Username [Redmine: #137144]
		- 20210731@Malcolm : Add alias [RedmineId : #151509] 
        - 20231011@Ned.Le: CRM - PIC Management performance issue: it takes so long to display data when searching by group headline (HotFix #195326)

	Param's Explanation:	
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @HeadlineName = ISNULL(@HeadlineName,''), @Username = ISNULL(@Username,'')

	CREATE TABLE #TmpLanguage
	(
		SettingID		INT,
		SettingValue	NVARCHAR(200)
	)
	
	CREATE TABLE #Tmp
	(
		PicID			INT,
		Username		NVARCHAR(200) PRIMARY KEY,
		Role			INT,
		PicType			INT,
		GroupHeadline	VARCHAR(1000),
		Language		VARCHAR(1000),
		Country			INT,
		IsActive		BIT,
		Remark			NVARCHAR(1000),
		RowNum			INT
	)
	
	SELECT @Role = ISNULL(@Role,'')

	INSERT INTO #Tmp
	(
			PicID,
			Username,
			Role,
			PicType,
			Language,
			Country,
			IsActive,
			Remark
	)
	SELECT p.PicID,
		   p.Username,
		   P.Role,
		   p.PicType,
		   p.Language,
		   p.Country,
		   p.IsActive,
		   p.Remark
	FROM dbo.crmPIC p WITH(NOLOCK)
	WHERE (@Username = '' OR p.Username LIKE '%' + @Username + '%') 
		AND (@Role = '' OR ',' + @Role + ',' LIKE '%,' + CONVERT(VARCHAR(20),p.[Role]) + ',%')

    CREATE TABLE #tmpHeadline (username VARCHAR(100), PicID INT)

    INSERT INTO #tmpHeadline (username, PicID)
	SELECT c.username, h.PicID
	FROM bodb02.dbo.Customer c WITH(NOLOCK)
		 INNER JOIN dbo.crmPICHeadline h WITH(NOLOCK) ON h.HeadlineID = c.custid

	DELETE #tmpHeadline
	WHERE username NOT LIKE '%' + @HeadlineName + '%'

	IF (@HeadlineName <> '')
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE t.PicID NOT IN (SELECT h.PicID FROM #tmpHeadline h)
	END

	SELECT  @TotalRows = COUNT(*)  FROM #Tmp

	INSERT INTO #TmpLanguage
	(
			SettingID,
			SettingValue
	)
	SELECT	SettingID,
			SettingValue
	FROM crmSetting WITH(NOLOCK)
	WHERE SettingName = 'Language' 

	UPDATE x
	SET x.RowNum = x.NewRowNum
	FROM(
		SELECT RowNum, 
			   ROW_NUMBER() OVER(ORDER BY t.IsActive DESC,t.Username) AS NewRowNum
		FROM #Tmp t
	)x

	IF @PageIndex >= 0 AND @PageSize > 0 
		DELETE p
		FROM #Tmp p
		WHERE RowNum < @RowStart OR RowNum > @RowEnd

	UPDATE p
	SET p.GroupHeadline = STUFF(l.username ,1,1,'') 
	FROM #Tmp p
	OUTER APPLY(
		 SELECT ',' + r.username 
		 FROM dbo.crmPICHeadline m WITH(NOLOCK) 		
			INNER JOIN bodb02.dbo.Customer r WITH(NOLOCK) ON  m.HeadlineID = r.custid
		 WHERE m.PicID = p.PicID 
		 GROUP BY r.username	
		 ORDER BY r.username
		 FOR XML PATH('')
	)as l(Username)

	SELECT	PicID, 
			Username,
			GroupHeadline,
			t.Role						AS [RoleID],
			ISNULL(s.SettingValue,'')	AS [RoleName], 	
			t.PicType					AS [PicType],
			ISNULL(pt.SettingValue,'')	AS [PicTypeName], 	
			ISNULL(l.Language,'')		AS [Language],
			ISNULL(c.CountryName,'')	AS CountryName,
			t.Country					AS CountryID,
			t.IsActive, 
			t.Remark,
			t.RowNum
	FROM #Tmp t
	LEFT JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.Role 
	LEFT JOIN dbo.crmCountry c WITH(NOLOCK) ON c.CountryID = t.Country 
	LEFT JOIN dbo.crmSetting pt WITH(NOLOCK) ON pt.SettingID = t.PicType 
	OUTER APPLY(
	    SELECT CONVERT(XML,(SELECT  l.SettingID AS '@Id',  l.SettingValue AS '@Value'
		FROM #TmpLanguage l WITH(NOLOCK) 
		WHERE ',' + t.Language + ',' LIKE '%,' + CONVERT(VARCHAR(20),l.SettingID) + ',%' 
		FOR XML PATH('Setting'),ROOT('ROOT')))
	) AS l(Language)
	ORDER BY IsActive DESC, Username

	SELECT p.PicID, 
	       e.SettingID,
		   e.SettingValue AS SettingName,
		   i.CommunicationValue AS [Value]
	FROM dbo.crmPIC p WITH(NOLOCK)
	    INNER JOIN dbo.crmPICCommunication i WITH(NOLOCK) ON p.PicID = i.PicID
		INNER JOIN dbo.crmSetting e WITH(NOLOCK) ON e.SettingID = i.CommunicationID AND e.IsActive = 1
    WHERE EXISTS(SELECT 1 FROM #Tmp t WHERE t.PicID = p.PicID)
	
	DROP TABLE #Tmp
	DROP TABLE #TmpLanguage
    DROP TABLE #tmpHeadline
END