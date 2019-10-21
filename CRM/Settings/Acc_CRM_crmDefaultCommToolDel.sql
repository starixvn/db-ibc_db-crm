/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_crmDefaultCommToolDel]  
(  
 @UserID			INT,  
 @DefaultCommID		INT,
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

	DELETE FROM [crmDefaultCommTool] WHERE DefaultCommID=@DefaultCommID	
	IF @ErrCode<>0
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Delete setting unsuccessfuly.'  		 
	END
 -- write log  
 DECLARE @LogElement XML  
  
 SELECT @LogElement =       
     '<Acc_CRM_crmDefaultCommToolDel>' + --SP Name  
      '<DefaultCommID>' + ISNULL(CONVERT(VARCHAR(10),@DefaultCommID),'')	+ '</DefaultCommID>' +  
	  '<UserID>' + ISNULL(CONVERT(VARCHAR(10),@UserID),'')	+ '</UserID>' +  
	  '<IP>' + ISNULL(@IP,'')								+ '</IP>' +  	
     '</Acc_CRM_crmDefaultCommToolDel>'  
      
  
 EXEC [dbo].[WriteLog_UserLog_crmLogSetting]  
     @SettingID = 0,   
     @ParentID = 0,   
     @UserID = @UserID,   
     @ActionID = 308,   
     @IP = @IP,   
     @NewValues = @LogElement  
END  

GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_crmDefaultCommToolDel] TO [bodbAdminNet]
GO 
