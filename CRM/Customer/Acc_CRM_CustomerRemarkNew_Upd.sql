/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNew_Upd] 
	 @RemarkID INT
	,@CustID INT 
	,@Remark NVARCHAR(MAX) 
	,@RemarkTitle INT 
	,@RelatedPICs  VARCHAR(1000) 
	,@Ext	INT 
	,@HandlerID INT 
	,@ApproverID INT 
	,@AcknowledgerID INT 
	,@Requester NVARCHAR(500) 
	,@UpdaterID INT 
	,@IP VARCHAR(15)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = ''	OUTPUT
AS
/*
	Created: 20220325@Winfred
	Task : CRM - Update special remarks renovation into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20220325@Winfred: CRM - Update special remarks renovation [RedmineId : #167941]
	
	Parameter's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.strSplit(@RelatedPICs,',') 
					WHERE NOT EXISTS (SELECT 1 FROM crmPIC WITH(NOLOCK) 
					WHERE PicID = SettingID) )
	BEGIN
		SELECT	@ErrCode = 101
			,	@ErrMsg = 'PIC does not exist in IBC system.';
		RETURN;
	END;
	
	DECLARE @CustID_old   INT    
			,@Remark_old    NVARCHAR(MAX)    
			,@RemarkTitle_old    INT    
			,@RelatedPICs_old        NVARCHAR(MAX)    
			,@Ext_old	INT    
			,@HandlerID_old   INT    
			,@ApproverID_old    INT    
			,@AcknowledgerID_old    INT    
			,@Requester_old    NVARCHAR(500)    
			,@UpdaterID_old    INT 
	
	SELECT
	@CustID_old          		=   CustID                   	
	,@Remark_old           		=   Remark                    	
	,@RemarkTitle_old          	=   RemarkTitle                
	,@RelatedPICs_old           =   RelatedPICs                 
	,@Ext_old					=   Ext			
	,@HandlerID_old           	=   HandlerID                  
	,@ApproverID_old           	=   ApproverID                 
	,@AcknowledgerID_old       	=   AcknowledgerID             
	,@Requester_old           	=   Requester                   
	,@UpdaterID_old           	=   UpdaterID   
	FROM  crmCustomerRemarkNew WITH(NOLOCK)
	WHERE RemarkID = @RemarkID
		
	UPDATE crmCustomerRemarkNew WITH(UPDLOCK,ROWLOCK)
	SET CustID               =   @CustID  ,         
		Remark               =   @Remark  ,         
		RemarkTitle          =   @RemarkTitle   ,   
		RelatedPICs          =   @RelatedPICs   ,   
		Ext                  =   @Ext           ,   
		HandlerID            =   @HandlerID      ,  
		ApproverID           =   @ApproverID     ,  
		AcknowledgerID       =   @AcknowledgerID  , 
		Requester            =   @Requester       , 
		UpdaterID            =   @UpdaterID      ,  
		LastUpdate           =   GETDATE()     ,  
		CreatedDate          =   CASE WHEN CreatorID IS NULL THEN GETDATE() ELSE CreatedDate END  , 
		CreatorID            =   CASE WHEN CreatorID IS NULL THEN @UpdaterID ELSE CreatorID END         
	WHERE RemarkID = @RemarkID
	
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'update remark unsuccessfuly.'
		RETURN
	END
	
	-- write log
	DECLARE @LogElement_old XML
	SELECT @LogElement_old = 				
					'<Acc_CRM_CustomerRemarkNew_Upd>' + --SP Name
						'<CustID>'		+ ISNULL(CONVERT(VARCHAR(10),@CustID_old),'')			+ '</CustID>' +
						'<Remark>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Remark_old),'')		+ '</Remark>' +
						'<RemarkTitle>'	+ ISNULL(CONVERT(VARCHAR(10),@RemarkTitle_old),'')		+ '</RemarkTitle>' +
						'<RelatedPICs>'	+ ISNULL(@RelatedPICs_old,'')							+ '</RelatedPICs>' +
						'<HandlerID>'		+ ISNULL(CONVERT(VARCHAR(10),@HandlerID_old),'')	+ '</HandlerID>' +
						'<ApproverID>'	+ ISNULL(CONVERT(VARCHAR(10),@ApproverID_old),'')		+ '</ApproverID>' +
						'<AcknowledgerID>'+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID_old),'')	+ '</AcknowledgerID>' +
						'<Requester>'	+ ISNULL(CONVERT(VARCHAR(10),@Requester_old),'')		+ '</Requester>' +
						'<UpdaterID>'		+ ISNULL(CONVERT(VARCHAR(10),@UpdaterID_old),'')	+ '</UpdaterID>' +
					'</Acc_CRM_CustomerRemarkNew_Upd>' 
	DECLARE @LogElement XML
	SELECT @LogElement = 				
					'<Acc_CRM_CustomerRemarkNew_Upd>' + --SP Name
						'<CustID>'		+ ISNULL(CONVERT(VARCHAR(10),@CustID),'')			+ '</CustID>' +
						'<Remark>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')		+ '</Remark>' +
						'<RemarkTitle>'	+ ISNULL(CONVERT(VARCHAR(10),@RemarkTitle),'')		+ '</RemarkTitle>' +
						'<RelatedPICs>'	+ ISNULL(@RelatedPICs,'')							+ '</RelatedPICs>' +
						'<HandlerID>'		+ ISNULL(CONVERT(VARCHAR(10),@HandlerID),'')	+ '</HandlerID>' +
						'<ApproverID>'	+ ISNULL(CONVERT(VARCHAR(10),@ApproverID),'')		+ '</ApproverID>' +
						'<AcknowledgerID>'+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID),'')	+ '</AcknowledgerID>' +
						'<Requester>'	+ ISNULL(CONVERT(VARCHAR(10),@Requester),'')		+ '</Requester>' +
						'<UpdaterID>'		+ ISNULL(CONVERT(VARCHAR(10),@UpdaterID),'')	+ '</UpdaterID>' +
					'</Acc_CRM_CustomerRemarkNew_Upd>' 

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UpdaterID, 
					@ActionID = 602, 
					@IP = @IP, 
					@OldValues = @LogElement_old,
					@NewValues = @LogElement
							
END	