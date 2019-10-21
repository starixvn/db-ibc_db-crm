/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_crmDefaultCommToolUpd]  
(  
 @UserID			INT,  
 @DefaultCommID		INT,
 @Category			NVARCHAR(MAX),
 @SubCategory		NVARCHAR(MAX),
 @Comm				NVARCHAR(MAX),
 @IP				VARCHAR(15),  
 @ErrCode			INT = 0 OUTPUT,  
 @ErrMsg			NVARCHAR(4000) = '' OUTPUT 
)  
AS  
/*  
Created: Winnie  
Date: 20191018
Task : Insert new setting  
DB: DBCRM/bodb_CRM  
Original:  
  
Revisions:  
 - 20191018@Winnie: CRM - Support Default Communication Tool RedmineID: #122078
Param's Explanation:  

*/  
BEGIN  
 SET NOCOUNT ON      
	
	DECLARE @tmpCategory	TABLE(CategoryID	INT)
	DECLARE @tmpSubCategory TABLE(SubCategoryID	INT)
	DECLARE @tmpComm		TABLE(CommID		INT)
	DECLARE	@CustID			INT
	
	DECLARE @CustomerCheck TABLE(CustID INT)
	DECLARE @Category_OLD			NVARCHAR(MAX),@SubCategory_OLD		NVARCHAR(MAX),@Comm_OLD				NVARCHAR(MAX)

	SELECT @CustID=CustID FROM [crmDefaultCommTool] WITH(NOLOCK) WHERE DefaultCommID=@DefaultCommID

	CREATE TABLE #tmp
	(
		[DefaultCommID] [int] NOT NULL,
		[CustID] [int] NOT NULL,
		[SettingID] [int] NOT NULL,
		[SettingType] [tinyint] NOT NULL,
	)

	INSERT INTO @tmpCategory(CategoryID)
	SELECT ltrim(rtrim(val))
	FROM dbo.f_CRM_strSplit(@Category,',')		

	INSERT INTO @tmpSubCategory(SubCategoryID)
	SELECT ltrim(rtrim(val))
	FROM dbo.f_CRM_strSplit(@SubCategory,',')		
		
	INSERT INTO @tmpComm(CommID)
	SELECT ltrim(rtrim(val))
	FROM dbo.f_CRM_strSplit(@Comm,',')		

	INSERT INTO @CustomerCheck(CustID)
	SELECT CustID
	FROM [crmDefaultCommTool] a WITH(NOLOCK) 		
	WHERE a.DefaultCommID<>0 AND a.custid=@CustID AND
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

	IF EXISTS(SELECT TOP 1 1 FROM @CustomerCheck)
	BEGIN
		 SELECT @ErrCode = 100, @ErrMsg = 'This setting exists, please check again!'
		 RETURN
	END
	
	INSERT INTO #tmp(
					[DefaultCommID]
					,[CustID]
					,[SettingID]
					,[SettingType])
	SELECT 
					[DefaultCommID]
					,[CustID]
					,[SettingID]
					,[SettingType]
	FROM [crmDefaultCommTool] WITH(NOLOCK) WHERE DefaultCommID=@DefaultCommID

	SELECT @Category_OLD= STUFF(
							(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
								FROM #tmp c								
								WHERE c.SettingType=1
								FOR xml path('')
							)
							, 1
							, 1
							, '')

	SELECT @SubCategory_OLD= STUFF(
						(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
							FROM #tmp c								
							WHERE c.SettingType=2
							FOR xml path('')
						)
						, 1
						, 1
						, '')

	SELECT @Comm_OLD= STUFF(
						(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
							FROM #tmp c								
							WHERE c.SettingType=3
							FOR xml path('')
						)
						, 1
						, 1
						, '')

	DELETE FROM [crmDefaultCommTool] WHERE DefaultCommID=@DefaultCommID	
	IF @@ERROR <> 0  
	BEGIN  
		SELECT @ErrCode = 100, @ErrMsg = 'Update setting unsuccessfuly.'  	
		RETURN  
	END  
	select @DefaultCommID
	INSERT INTO [crmDefaultCommTool]([DefaultCommID],[CustID],[SettingID],[SettingType])
	SELECT @DefaultCommID,@CustID,CategoryID,1
	FROM @tmpCategory
	IF @@ERROR <> 0  
	BEGIN  
		SELECT @ErrCode = 101, @ErrMsg = 'Update setting unsuccessfuly.'  
		DELETE FROM [crmDefaultCommTool] WHERE [DefaultCommID]=@DefaultCommID 
		INSERT INTO [crmDefaultCommTool](
					[DefaultCommID]
					,[CustID]
					,[SettingID]
					,[SettingType])
		SELECT 
						[DefaultCommID]
						,[CustID]
						,[SettingID]
						,[SettingType]
		FROM #tmp WITH(NOLOCK)
		RETURN  
	END  

	INSERT INTO [crmDefaultCommTool]([DefaultCommID],[CustID],[SettingID],[SettingType])
	SELECT @DefaultCommID,@CustID,SubCategoryID,2
	FROM @tmpSubCategory		
	IF @@ERROR <> 0  
	BEGIN  
		SELECT @ErrCode = 102, @ErrMsg = 'Update setting unsuccessfuly.'  
		DELETE FROM [crmDefaultCommTool] WHERE [DefaultCommID]=@DefaultCommID 
		INSERT INTO [crmDefaultCommTool](
					[DefaultCommID]
					,[CustID]
					,[SettingID]
					,[SettingType])
		SELECT 
						[DefaultCommID]
						,[CustID]
						,[SettingID]
						,[SettingType]
		FROM #tmp WITH(NOLOCK)
		RETURN   
	END  

	INSERT INTO [crmDefaultCommTool]([DefaultCommID],[CustID],[SettingID],[SettingType])
	SELECT @DefaultCommID,@CustID,CommID,3
	FROM @tmpComm
	IF @@ERROR <> 0  
	BEGIN  
		SELECT @ErrCode = 103, @ErrMsg = 'Update setting unsuccessfuly.'  
		DELETE FROM [crmDefaultCommTool] WHERE [DefaultCommID]=@DefaultCommID 
		INSERT INTO [crmDefaultCommTool](
					[DefaultCommID]
					,[CustID]
					,[SettingID]
					,[SettingType])
		SELECT 
						[DefaultCommID]
						,[CustID]
						,[SettingID]
						,[SettingType]
		FROM #tmp WITH(NOLOCK)
		RETURN  
	END  

 -- write log  
 DECLARE @LogElement XML  
 DECLARE @LogElement_OLD XML 
  
 SELECT @LogElement =       
     '<Acc_CRM_crmDefaultCommToolUpd>' + --SP Name  
	  '<CustID>' + ISNULL(CONVERT(VARCHAR(10),@CustID),'')	+ '</CustID>' +  
	  '<DefaultCommID>' + ISNULL(CONVERT(VARCHAR(10),@DefaultCommID),'')	+ '</DefaultCommID>' +      
      '<Category>' + ISNULL(@Category,'')       + '</Category>' +  
	  '<SubCategory>' + ISNULL(@SubCategory,'') + '</SubCategory>' +  
      '<Comm>' + ISNULL(@Comm,'')				+ '</Comm>' +  
	  '<UserID>' + ISNULL(CONVERT(VARCHAR(10),@UserID),'')	+ '</UserID>' +  
	  '<IP>' + ISNULL(@IP,'')								+ '</IP>' +  	
     '</Acc_CRM_crmDefaultCommToolUpd>'  

 SELECT @LogElement_OLD =       
     '<Acc_CRM_crmDefaultCommToolUpd>' + --SP Name  
	  '<CustID>' + ISNULL(CONVERT(VARCHAR(10),@CustID),'')	+ '</CustID>' +  
	  '<DefaultCommID>' + ISNULL(CONVERT(VARCHAR(10),@DefaultCommID),'')	+ '</DefaultCommID>' +      
      '<Category>' + ISNULL(@Category_OLD,'')       + '</Category>' +  
	  '<SubCategory>' + ISNULL(@SubCategory_OLD,'')		+ '</SubCategory>' +  
      '<Comm>' + ISNULL(@Comm_OLD,'')					+ '</Comm>' +  
	  '<UserID>' + ISNULL(CONVERT(VARCHAR(10),@UserID),'')	+ '</UserID>' +  
	  '<IP>' + ISNULL(@IP,'')								+ '</IP>' +  	
     '</Acc_CRM_crmDefaultCommToolUpd>'  
      
  
 EXEC [dbo].[WriteLog_UserLog_crmLogSetting]  
     @SettingID = 0,   
     @ParentID = 0,   
     @UserID = @UserID,   
     @ActionID = 307,   
     @IP = @IP,   
     @NewValues = @LogElement,
	 @OldValues = @LogElement_OLD  
END  

GO 
 GRANT EXECUTE ON [dbo].Acc_CRM_crmDefaultCommToolUpd TO [bodbAdminNet]
GO 
