/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNewUpd] 
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
	,@ModifierID INT 
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
	
	IF EXISTS (SELECT TOP 1 1 FROM STRING_SPLIT(@RelatedPICs,',') 
					WHERE  value <> '' AND NOT EXISTS (SELECT 1 FROM crmPIC WITH(NOLOCK) 
					WHERE PicID = value) )
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
			,@ModifierID_old    INT 
			,@CreatorID_old INT 
			,@LastUpdate DATETIME 
			,@CreatedDate DATETIME
			,@NewUpdate DATETIME  
	
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
	,@ModifierID_old           	=   ModifierID
	,@CreatedDate				=	CreatedDate
	,@CreatorID_old				=	CreatorID 
	,@LastUpdate				=	LastUpdate   
	FROM  crmCustomerRemarkNew WITH(NOLOCK)
	WHERE RemarkID = @RemarkID
	
	SET @NewUpdate = GETDATE()
		
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
		ModifierID            =  @ModifierID      ,  
		LastUpdate           =   @NewUpdate     ,  
		CreatedDate          =   CASE WHEN CreatorID IS NULL THEN GETDATE() ELSE CreatedDate END  , 
		CreatorID            =   CASE WHEN CreatorID IS NULL THEN @ModifierID ELSE CreatorID END         
	WHERE RemarkID = @RemarkID
	
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'update remark unsuccessfuly.'
		RETURN
	END
	
	IF EXISTS(SELECT TOP 1 1 FROM crmCustomerRemarkNew WITH(NOLOCK) WHERE ISNULL(CreatorID,0) <> 0 )
	BEGIN
		DECLARE @LogHistory VARCHAR(MAX)
		SELECT @LogHistory = '<Root>' +
		   CASE WHEN @Remark_old <> @Remark THEN  '<Remark>'   + ISNULL([dbo].[f_EncodeXMLValue](@Remark_old),'') + '</Remark>'  ELSE '' END  +  
		   CASE WHEN @RemarkTitle_old <> @RemarkTitle THEN '<RemarkTitle>'  +  ISNULL(CONVERT(VARCHAR(10),@RemarkTitle_old),'') + '</RemarkTitle>' ELSE '' END  +  
		   CASE WHEN @RelatedPICs_old <> @RelatedPICs THEN '<RelatedPICs>'  +  ISNULL(@RelatedPICs_old,'')  + '</RelatedPICs>'  ELSE '' END +  
		   CASE WHEN @Ext_old <> @Ext THEN '<Ext>'    +ISNULL(CONVERT(VARCHAR(10),@Ext_old),'')   + '</Ext>'  ELSE '' END +  
		   CASE WHEN @HandlerID_old <> @HandlerID THEN '<HandlerID>'  + ISNULL(CONVERT(VARCHAR(10),@HandlerID_old),'') + '</HandlerID>' ELSE '' END + 
		   CASE WHEN @ApproverID_old <> @ApproverID THEN '<ApproverID>'  +  ISNULL(CONVERT(VARCHAR(10),@ApproverID_old),'') + '</ApproverID>'  ELSE '' END +  
		   CASE WHEN @AcknowledgerID_old <> @AcknowledgerID THEN '<AcknowledgerID>' +  ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID_old),'')  + '</AcknowledgerID>'  ELSE '' END +  
		   CASE WHEN @Requester_old <> @Requester THEN '<Requester>'  +  ISNULL(CONVERT(VARCHAR(10),@Requester_old),'') + '</Requester>'  ELSE '' END +  
		   CASE WHEN @ModifierID_old <> @ModifierID THEN '<ModifierID>'  +  ISNULL(CONVERT(VARCHAR(10),@ModifierID_old),'') + '</ModifierID>'  ELSE '' END  +  
		'</Root>' 
		INSERT INTO crmCustomerRemarkHistory(RemarkID,CustID,Logdata,ModifierID,LastUpdate)
		VALUES(@RemarkID,@CustID,@LogHistory,@ModifierID,@NewUpdate)
	END
	
	-- write log
	DECLARE @LogElement_old XML
	SELECT @LogElement_old = 				
					'<R>' + --SP Name
						'<CustID>'		+ ISNULL(CONVERT(VARCHAR(10),@CustID_old),'')			+ '</CustID>' +
						'<Remark>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Remark_old),'')		+ '</Remark>' +
						'<RemarkTitle>'	+ ISNULL(CONVERT(VARCHAR(10),@RemarkTitle_old),'')		+ '</RemarkTitle>' +
						'<RelatedPICs>'	+ ISNULL(@RelatedPICs_old,'')							+ '</RelatedPICs>' +
						'<Ext>'			+ ISNULL(CONVERT(VARCHAR(10),@Ext_old),'')				+ '</Ext>' +
						'<HandlerID>'		+ ISNULL(CONVERT(VARCHAR(10),@HandlerID_old),'')	+ '</HandlerID>' +
						'<ApproverID>'	+ ISNULL(CONVERT(VARCHAR(10),@ApproverID_old),'')		+ '</ApproverID>' +
						'<AcknowledgerID>'+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID_old),'')	+ '</AcknowledgerID>' +
						'<Requester>'	+ ISNULL(CONVERT(VARCHAR(10),@Requester_old),'')		+ '</Requester>' +
						'<ModifierID>'		+ ISNULL(CONVERT(VARCHAR(10),@ModifierID_old),'')	+ '</ModifierID>' +
						'<CreatorID>'	+ ISNULL(CONVERT(VARCHAR(10),@CreatorID_old),'')		+ '</CreatorID>' +
						'<LastUpdate>'		+ ISNULL(CONVERT(VARCHAR(20),@LastUpdate),'')		+ '</LastUpdate>' +
						'<CreatedDate>'		+ ISNULL(CONVERT(VARCHAR(20),@CreatedDate),'')		+ '</CreatedDate>' +
					'</R>' 
	DECLARE @LogElement XML
	SELECT @LogElement = 				
					'<R>' + --SP Name
						'<CustID>'		+ ISNULL(CONVERT(VARCHAR(10),@CustID),'')			+ '</CustID>' +
						'<Remark>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')		+ '</Remark>' +
						'<RemarkTitle>'	+ ISNULL(CONVERT(VARCHAR(10),@RemarkTitle),'')		+ '</RemarkTitle>' +
						'<RelatedPICs>'	+ ISNULL(@RelatedPICs,'')							+ '</RelatedPICs>' +
						'<Ext>'			+ ISNULL(CONVERT(VARCHAR(10),@Ext),'')				+ '</Ext>' +
						'<HandlerID>'		+ ISNULL(CONVERT(VARCHAR(10),@HandlerID),'')	+ '</HandlerID>' +
						'<ApproverID>'	+ ISNULL(CONVERT(VARCHAR(10),@ApproverID),'')		+ '</ApproverID>' +
						'<AcknowledgerID>'+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID),'')	+ '</AcknowledgerID>' +
						'<Requester>'	+ ISNULL(CONVERT(VARCHAR(10),@Requester),'')		+ '</Requester>' +
						'<ModifierID>'		+ ISNULL(CONVERT(VARCHAR(10),@ModifierID),'')	+ '</ModifierID>' +
						'<CreatorID>'	+ ISNULL(CONVERT(VARCHAR(10),@CreatorID_old),'')	+ '</CreatorID>' +
						'<LastUpdate>'		+ ISNULL(CONVERT(VARCHAR(20),@NewUpdate),'')	+ '</LastUpdate>' +
						'<CreatedDate>'		+ ISNULL(CONVERT(VARCHAR(20),@CreatedDate),'')	+ '</CreatedDate>' +
					'</R>' 

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @ModifierID, 
					@ActionID = 602, 
					@IP = @IP, 
					@OldValues = @LogElement_old,
					@NewValues = @LogElement
							
END	