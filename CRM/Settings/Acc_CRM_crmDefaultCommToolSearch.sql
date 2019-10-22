/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_crmDefaultCommToolSearch
(
					@Username			NVARCHAR(MAX)=NULL,
					@Category			NVARCHAR(MAX),
					@SubCategory		NVARCHAR(MAX),
					@PageSize				INT = 0,
					@PageIndex				INT = 0,
					@TotalRows				INT = 0 OUTPUT
					)
AS
/*
	Created:	Winnie
	Date:		20191017
	Task:		Select Communication 
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20191017@Winnie:	Select Communication RedmineID: #122087
	
*/
BEGIN
	DECLARE @RowStart INT, @RowEnd INT 
	
	SELECT @PageIndex = @PageIndex - 1
			,@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1

	CREATE TABLE #MainCategory(SettingID INT PRIMARY KEY,SettingValue NVARCHAR(100))
	INSERT INTO #MainCategory(SettingID,SettingValue)
	SELECT SettingID,SettingValue
	FROM [dbo].[crmSetting] WITH(NOLOCK) WHERE [SettingName]='MainCategory'
	UNION ALL
	SELECT 0,'Any'

	CREATE TABLE #SubCategory(SettingID INT PRIMARY KEY,SettingValue NVARCHAR(100))
	INSERT INTO #SubCategory(SettingID,SettingValue)
	SELECT SettingID,SettingValue
	FROM [dbo].[crmSetting] WITH(NOLOCK) WHERE [SettingName]='SubCategory'
	UNION ALL
	SELECT 0,'Any'

	CREATE TABLE #tmp (DefaultCommID INT,UserName NVARCHAR(50),Category VARCHAR(MAX),SubCategory VARCHAR(MAX),CommTool VARCHAR(MAX))

	INSERT INTO #tmp(DefaultCommID ,UserName ,Category ,SubCategory ,CommTool)
	SELECT DISTINCT
	 a.DefaultCommID,
     cc.UserName 
	  ,STUFF(
						(   SELECT ',' + b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN #MainCategory b  ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [Category]
     
	    ,STUFF(
						(   SELECT ','+ b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN #SubCategory b  ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=2
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [SubCategory]

		,STUFF(
						(   SELECT ',' + b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN crmSetting b WITH(NOLOCK) ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=3
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [CommTool]   
	FROM [crmDefaultCommTool] a WITH(NOLOCK) 	
		INNER JOIN crmCustomer cc WITH(NOLOCK) ON a.CustID=cc.CustID	
	WHERE a.DefaultCommID<>0 AND  (UserName LIKE '%'+@Username+'%' OR @Username IS NULL) AND
		STUFF(
							(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
								FROM [crmDefaultCommTool] c WITH(NOLOCK)									
								WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
								FOR xml path('')
							)
							, 1
							, 1
							, '')=@Category
		AND 
		STUFF(
						(   SELECT ','+ CONVERT(  varchar(50),c.settingID)
							FROM [crmDefaultCommTool] c WITH(NOLOCK)								
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=2
							FOR xml path('')
						)
						, 1
						, 1
						, '') =@SubCategory
	IF @TotalRows=0
	BEGIN
		SELECT @TotalRows=COUNT(1) FROM #tmp
	END
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT * FROM #tmp
	END
	ELSE 
	BEGIN
		WITH pag as
		(
			SELECT DefaultCommID, ROW_NUMBER() OVER(ORDER BY DefaultCommID DESC) AS RowNum 
			FROM #tmp
		)
		SELECT 	*
		FROM #tmp(NOLOCK) c 
			INNER JOIN pag ON c.DefaultCommID = pag.DefaultCommID
		WHERE pag.RowNum BETWEEN @RowStart AND @RowEnd
	END
END;
GO



