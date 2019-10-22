/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_crmDefaultCommToolSel
					@DefaultCommID			INT			
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

select * from crmSetting
	SELECT DISTINCT a.[DefaultCommID]
      ,[CustID]
	  ,STUFF(
						(   SELECT ','+ b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN #MainCategory b WITH(NOLOCK) ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID=a.DefaultCommID
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [Category]
     
	    ,STUFF(
						(   SELECT ','+ b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN #SubCategory b WITH(NOLOCK) ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID = a.[DefaultCommID]
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
	WHERE [DefaultCommID]=@DefaultCommID

END;
GO

