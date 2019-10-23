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

	SELECT DISTINCT a.[DefaultCommID]
      ,[CustID]
	  ,STUFF(
						(   SELECT ','+ CAST(c.settingID AS VARCHAR(50))
							FROM [crmDefaultCommTool] c WITH(NOLOCK)							
							WHERE c.DefaultCommID=a.DefaultCommID AND c.SettingType=1
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [Category]
     
	    ,STUFF(
						(   SELECT ','+ CAST(c.settingID AS VARCHAR(50))
							FROM [crmDefaultCommTool] c WITH(NOLOCK)								
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=2
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [SubCategory]

		,STUFF(
						(   SELECT ','+ CAST(c.settingID AS VARCHAR(50))
							FROM [crmDefaultCommTool] c WITH(NOLOCK)							
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

