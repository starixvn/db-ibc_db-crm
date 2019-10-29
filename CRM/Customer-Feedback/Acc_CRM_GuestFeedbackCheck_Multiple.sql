/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_GuestFeedbackCheck_Multiple]  
(   
 @ListCustID		VARCHAR(MAX)=NULL,
 @Category			NVARCHAR(MAX),
 @SubCategory		NVARCHAR(MAX), 
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
	DECLARE @tmpUserName TABLE (USERNAME NVARCHAR(50),CustId INT PRIMARY KEY)
	DECLARE @iDoc INT,@CommunicationID			VARCHAR(MAX),@CustID INT
	CREATE TABLE #NotExistedDefault(CustID INT,USERNAME NVARCHAR(50))

	EXEC sp_xml_preparedocument @iDoc OUTPUT
		, @ListCustID

	INSERT INTO @tmpUserName(CustID ,UserName)
	SELECT *
		FROM OPENXML(@iDoc, '/ROOT/Cust', 1) WITH (
				  CustID		INT
				, Username		NVARCHAR(50)			
				)

	EXEC sp_xml_removedocument @iDoc
	WHILE EXISTS(SELECT TOP 1 CustID FROM @tmpUserName)
	BEGIN	
		SELECT @CommunicationID=STUFF(
							(   SELECT ','  + CONVERT(  varchar(50),c.settingID)
								FROM [crmDefaultCommTool] c WITH(NOLOCK)								
								WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=3
								FOR xml path('')
							)
							, 1
							, 1
							, '') 
			FROM [crmDefaultCommTool] a WITH(NOLOCK) 			
			WHERE a.DefaultCommID<>0 AND a.CustID=@CustID AND
				STUFF(
									(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
										FROM [crmDefaultCommTool] c WITH(NOLOCK)									
										WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
										ORDER BY c.SettingID ASC
										FOR xml path('')
									)
									, 1
									, 1
									, '')=@Categorystr
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
								, '') =@SubCategorystr
			IF @CommunicationID IS NULL
			BEGIN
				SELECT @CommunicationID=STUFF(
							(   SELECT ','  + CONVERT(  varchar(50),c.settingID)
								FROM [crmDefaultCommTool] c WITH(NOLOCK)								
								WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=3
								FOR xml path('')
							)
							, 1
							, 1
							, '') 
				FROM [crmDefaultCommTool] a WITH(NOLOCK) 			
				WHERE a.DefaultCommID<>0 AND a.CustID=@CustID AND
					STUFF(
								(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
									FROM [crmDefaultCommTool] c WITH(NOLOCK)									
									WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
									ORDER BY c.SettingID ASC
									FOR xml path('')
								)
								, 1
								, 1
								, '')=@Categorystr
					AND 
					EXISTS(SELECT TOP 1 1
											FROM [crmDefaultCommTool] c WITH(NOLOCK)									
											WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingID=0 AND c.SettingType=2)
			END
			IF @CommunicationID IS NULL
			BEGIN
				SELECT @CommunicationID=STUFF(
							(   SELECT ','  + CONVERT(  varchar(50),c.settingID)
								FROM [crmDefaultCommTool] c WITH(NOLOCK)								
								WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=3
								FOR xml path('')
							)
							, 1
							, 1
							, '') 
				FROM [crmDefaultCommTool] a WITH(NOLOCK) 			
				WHERE a.DefaultCommID<>0 AND a.CustID=@CustID AND
					 EXISTS(SELECT TOP 1 1
											FROM [crmDefaultCommTool] c WITH(NOLOCK)									
											WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingID=0 AND c.SettingType=1)
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
									, '') =@SubCategorystr

			END
			
			IF @CommunicationID IS NULL
			BEGIN
				SELECT @CommunicationID=STUFF(
							(   SELECT ','  + CONVERT(  varchar(50),c.settingID)
								FROM [crmDefaultCommTool] c WITH(NOLOCK)								
								WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=3
								FOR xml path('')
							)
							, 1
							, 1
							, '') 
				FROM [crmDefaultCommTool] a WITH(NOLOCK) 			
				WHERE a.DefaultCommID<>0 AND a.CustID=@CustID AND
					EXISTS(SELECT TOP 1 1
											FROM [crmDefaultCommTool] c WITH(NOLOCK)									
											WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingID=0 AND c.SettingType=1)
					AND 
					EXISTS(SELECT TOP 1 1
											FROM [crmDefaultCommTool] c WITH(NOLOCK)									
											WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingID=0 AND c.SettingType=2)
			END
			IF @CommunicationID IS NULL OR @CommunicationID=''
			BEGIN
				--SELECT @CommunicationID='1005'
				INSERT INTO #NotExistedDefault(CustID,USERNAME)
				SELECT CustID,USERNAME
				FROM @tmpUserName WHERE CustId=@CustID
			END
	END
	IF EXISTS(SELECT TOP 1 1 FROM #NotExistedDefault)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'The '+STUFF(
																					(   SELECT ',' + UserName
																						FROM #NotExistedDefault
																						FOR xml path('')
																					)
																					, 1
																					, 1
																					, '') +' do not have any default communication, so we cannot create feedback for them!'
	END
END

GO 
