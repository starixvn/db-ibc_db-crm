/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_crmDefaultCommToolIns]  
(  
 @UserID			INT,  
 @ListCustID		VARCHAR(MAX)=NULL,
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
			<ROOT>
				<Cust 
						CustID="1" 
						Username="20" 					
				/>
			</ROOT>	 
*/  
BEGIN  

 SET NOCOUNT ON      
	
	DECLARE @tmpCategory	TABLE(CategoryID	INT)
	DECLARE @tmpSubCategory TABLE(SubCategoryID	INT)
	DECLARE @tmpComm		TABLE(CommID		INT)
	DECLARE	@CustID			INT
	DECLARE	@MaxID			INT

	CREATE TABLE #Customer(CustID INT PRIMARY KEY, UserName NVARCHAR(50))
	CREATE TABLE #CustomerCheck (CustID INT PRIMARY KEY, UserName NVARCHAR(50))

	INSERT INTO @tmpCategory(CategoryID)
	SELECT ltrim(rtrim(val))
	FROM dbo.f_CRM_strSplit(@Category,',')		

	INSERT INTO @tmpSubCategory(SubCategoryID)
	SELECT ltrim(rtrim(val))
	FROM dbo.f_CRM_strSplit(@SubCategory,',')		
		
	INSERT INTO @tmpComm(CommID)
	SELECT ltrim(rtrim(val))
	FROM dbo.f_CRM_strSplit(@Comm,',')		
	
	DECLARE @iDoc INT

	EXEC sp_xml_preparedocument @iDoc OUTPUT
		, @ListCustID

	INSERT INTO #Customer(CustID ,UserName)
	SELECT *
		FROM OPENXML(@iDoc, '/ROOT/Cust', 1) WITH (
				  CustID		INT
				, Username		NVARCHAR(50)			
				)

	EXEC sp_xml_removedocument @iDoc

	INSERT INTO #CustomerCheck(CustID,UserName)
	SELECT DISTINCT cc.CustID,cc.UserName
	FROM [crmDefaultCommTool] a WITH(NOLOCK) 	
		INNER JOIN #Customer cc ON a.CustID=cc.CustID	
	WHERE a.DefaultCommID<>0 AND 
		STUFF(
							(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
								FROM [crmDefaultCommTool] c WITH(NOLOCK)									
								WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
								ORDER BY c.SettingID ASC
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
							ORDER BY c.SettingID ASC
							FOR xml path('')
						)
						, 1
						, 1
						, '') =@SubCategory

	IF EXISTS(SELECT TOP 1 1 FROM #CustomerCheck)
	BEGIN
		 SELECT @ErrCode = 100, @ErrMsg = 'This setting exists in these customer(s): '+STUFF(
																						(   SELECT ',' + UserName
																							FROM #CustomerCheck
																							FOR xml path('')
																						)
																						, 1
																						, 1
																						, '') +'. Please check again!'
		 

		 RETURN
	END

	WHILE EXISTS(SELECT TOP 1 1 FROM #Customer)
	BEGIN
		SELECT TOP 1 @CustID=CustID FROM #Customer

		SELECT @MaxID=MAX([DefaultCommID]) FROM [dbo].[crmDefaultCommTool] WITH(NOLOCK)

		INSERT INTO [crmDefaultCommTool]([DefaultCommID],[CustID],[SettingID],[SettingType])
		SELECT @MaxID+1,@CustID,CategoryID,1
		FROM @tmpCategory

		 IF @@ERROR <> 0  
		  BEGIN  
		   SELECT @ErrCode = 101, @ErrMsg = 'Create new setting unsuccessfuly.'  
		   DELETE FROM [crmDefaultCommTool] WHERE [DefaultCommID]>@MaxID AND custid IN (SELECT CustID FROM #Customer)
		   RETURN  
		  END  

		INSERT INTO [crmDefaultCommTool]([DefaultCommID],[CustID],[SettingID],[SettingType])
		SELECT @MaxID+1,@CustID,SubCategoryID,2
		FROM @tmpSubCategory
		
		 IF @@ERROR <> 0  
		  BEGIN  
		   SELECT @ErrCode = 102, @ErrMsg = 'Create new setting unsuccessfuly.'  
		   DELETE FROM [crmDefaultCommTool] WHERE [DefaultCommID]>@MaxID AND custid IN (SELECT CustID FROM #Customer)
		   RETURN  
		  END  

		INSERT INTO [crmDefaultCommTool]([DefaultCommID],[CustID],[SettingID],[SettingType])
		SELECT @MaxID+1,@CustID,CommID,3
		FROM @tmpComm
		 IF @@ERROR <> 0  
		  BEGIN  
		   SELECT @ErrCode = 103, @ErrMsg = 'Create new setting unsuccessfuly.' 
		   DELETE FROM [crmDefaultCommTool] WHERE [DefaultCommID]>@MaxID AND custid IN (SELECT CustID FROM #Customer)
		   RETURN  
		  END  

		DELETE FROM #Customer WHERE CustID=@CustID
	END

 -- write log  
 DECLARE @LogElement XML  
  
 SELECT @LogElement =       
     '<Acc_CRM_crmDefaultCommToolIns>' + --SP Name  
      '<ListCustID>'  + ISNULL(@ListCustID,'')      + '</ListCustID>'  +  
      '<Category>' + ISNULL(@Category,'')       + '</Category>' + 
	  '<SubCategory>' + ISNULL(@SubCategory,'') + '</SubCategory>' +  
      '<Comm>' + ISNULL(@Comm,'')				+ '</Comm>' +  
	  '<UserID>' + ISNULL(CONVERT(VARCHAR(10),@UserID),'')	+ '</UserID>' +  
	  '<IP>' + ISNULL(@IP,'')								+ '</IP>' +  	
     '</Acc_CRM_crmDefaultCommToolIns>'  
      
  
 EXEC [dbo].[WriteLog_UserLog_crmLogSetting]  
     @SettingID = 0,   
     @ParentID = 0,   
     @UserID = @UserID,   
     @ActionID = 306,   
     @IP = @IP,   
     @NewValues = @LogElement  
END  

GO 
 GRANT EXECUTE ON [dbo].Acc_CRM_crmDefaultCommToolIns TO [bodbAdminNet]
GO 
