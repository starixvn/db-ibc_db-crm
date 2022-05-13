/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNewUpd] 
	 @RemarkID INT= Null
	,@CustID INT = Null
	,@Remark NVARCHAR(MAX) = Null
	,@RemarkTitle INT = Null
	,@RelatedPICs  VARCHAR(1000) = Null
	,@Ext	INT = Null
	,@HandlerID INT = Null
	,@ApproverID INT = Null
	,@AcknowledgerID INT = Null
	,@Requester NVARCHAR(500) = Null
	,@ModifierID INT = Null
	,@IP VARCHAR(15)= Null
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
	
	IF IsNull(@RelatedPICs,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM STRING_SPLIT(@RelatedPICs,',') 
					WHERE  value <> '' AND NOT EXISTS (SELECT 1 FROM crmPIC WITH(NOLOCK) 
					WHERE PicID = value) )
	BEGIN
		SELECT	@ErrCode = 101
			,	@ErrMsg = 'PIC does not exist in IBC system.';
		RETURN;
	END;
	
	DECLARE @Remark_old NVARCHAR(MAX) ,@RemarkTitle_old INT ,@RelatedPICs_old NVARCHAR(MAX) ,@Ext_old	INT ,@HandlerID_old INT    
			,@ApproverID_old INT ,@AcknowledgerID_old INT ,@Requester_old NVARCHAR(500) ,@ModifierID_old INT ,@CreatorID_old INT 
			,@CreatedDate DATETIME ,@NewUpdate DATETIME ,@CreatedDate_old DATETIME ,@LastUpdate_old	 DATETIME ,@UserName NVARCHAR(50) ,@Creator NVARCHAR(50)
			,@Handler NVARCHAR(50) ,@Acknowledger NVARCHAR(50) ,@Approver NVARCHAR(50) ,@RemarkName NVARCHAR(100) ,@ExtStation NVARCHAR(100)
			,@Updater NVARCHAR(50) ,@Handler_old NVARCHAR(50) ,@Acknowledger_old NVARCHAR(50) ,@Approver_old NVARCHAR(50) ,@RemarkName_old NVARCHAR(100) ,@ExtStation_old NVARCHAR(100) ,@Updater_old NVARCHAR(50)
	
	SELECT              	
	@Remark_old           		=   Remark                    	
	,@RemarkTitle_old          	=   RemarkTitle                
	,@RelatedPICs_old           =   RelatedPICs                 
	,@Ext_old					=   Ext			
	,@HandlerID_old           	=   HandlerID                  
	,@ApproverID_old           	=   ApproverID                 
	,@AcknowledgerID_old       	=   AcknowledgerID             
	,@Requester_old           	=   Requester                   
	,@ModifierID_old           	=   ModifierID
	,@CreatedDate_old			=	CreatedDate
	,@CreatorID_old				=	CreatorID 
	,@LastUpdate_old			=	LastUpdate   
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
		CreatedDate          =   CASE WHEN CreatorID IS NULL THEN @NewUpdate ELSE CreatedDate END  , 
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
		CASE WHEN @Remark_old IS NULL AND @Remark IS NOT NULL THEN '<Remark>NULL</Remark>' ELSE 
				(CASE WHEN @Remark_old <> @Remark THEN  '<Remark>'+[dbo].[f_EncodeXMLValue](@Remark_old)+'</Remark>' ELSE '' END) END +  
		CASE WHEN @RemarkTitle_old IS NULL AND @RemarkTitle IS NOT NULL THEN '<RemarkTitle>NULL</RemarkTitle>' ELSE 
				(CASE WHEN  @RemarkTitle_old <> @RemarkTitle THEN '<RemarkTitle>'+CONVERT(VARCHAR(10),@RemarkTitle_old)+'</RemarkTitle>' ELSE '' END) END   +  
		CASE WHEN @RelatedPICs_old IS NULL AND @RelatedPICs IS NOT NULL THEN '<RelatedPICs>NULL</RelatedPICs>' ELSE 
				(CASE WHEN @RelatedPICs_old <> @RelatedPICs THEN '<RelatedPICs>'+@RelatedPICs_old+'</RelatedPICs>' ELSE '' END) END +  
		CASE WHEN @Ext_old IS NULL AND @Ext IS NOT NULL THEN '<Ext>NULL</Ext>' ELSE 
				(CASE WHEN @Ext_old <> @Ext THEN '<Ext>' +CONVERT(VARCHAR(10),@Ext_old) + '</Ext>'  ELSE '' END) END +  
		CASE WHEN @HandlerID_old IS NULL AND @HandlerID IS NOT NULL THEN '<HandlerID>NULL</HandlerID>' ELSE 
				(CASE WHEN @HandlerID_old <> @HandlerID THEN '<HandlerID>'  + CONVERT(VARCHAR(10),@HandlerID_old)+ '</HandlerID>' ELSE '' END) END + 
		CASE WHEN @ApproverID_old IS NULL AND @ApproverID IS NOT NULL THEN '<ApproverID>NULL</ApproverID>' ELSE 
					(CASE WHEN @ApproverID_old <> @ApproverID THEN '<ApproverID>'  +  CONVERT(VARCHAR(10),@ApproverID_old) + '</ApproverID>'  ELSE '' END) END +  
		CASE WHEN @AcknowledgerID_old IS NULL AND @AcknowledgerID IS NOT NULL THEN '<AcknowledgerID>NULL</AcknowledgerID>' ELSE 
				(CASE WHEN @AcknowledgerID_old <> @AcknowledgerID THEN '<AcknowledgerID>' +  CONVERT(VARCHAR(10),@AcknowledgerID_old)  + '</AcknowledgerID>'  ELSE '' END) END +  
		CASE WHEN @Requester_old IS NULL AND @Requester IS NOT NULL THEN '<Requester>NULL</Requester>' ELSE 
				(CASE WHEN @Requester_old <> @Requester THEN '<Requester>' + CONVERT(VARCHAR(10),@Requester_old) + '</Requester>'  ELSE '' END) END +  
		CASE WHEN @ModifierID_old IS NULL AND @ModifierID IS NOT NULL THEN '<ModifierID>NULL</ModifierID>' ELSE 
				(CASE WHEN @ModifierID_old <> @ModifierID THEN '<ModifierID>'  +  CONVERT(VARCHAR(10),@ModifierID_old) + '</ModifierID>'  ELSE '' END) END  +  
		'</Root>' 
		INSERT INTO crmCustomerRemarkHistory(RemarkID,CustID,Logdata,ModifierID,LastUpdate)
		VALUES(@RemarkID,@CustID,@LogHistory,@ModifierID,@NewUpdate)
	END
	
	SELECT @UserName = UserName FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID
	SELECT @Creator = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @CreatorID_old
	SELECT @RemarkName_old = SettingValue FROM crmSetting WITH(NOLOCK) WHERE SettingID = @RemarkTitle_old AND SettingName = 'RemarkTitles'
	SELECT @Handler_old = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @HandlerID_old
	SELECT @Acknowledger_old = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @AcknowledgerID_old
	SELECT @Approver_old = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @ApproverID_old
	SELECT @Updater_old = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @ModifierID_old
	SELECT @ExtStation_old = SettingValue FROM crmSetting WITH(NOLOCK) WHERE SettingID = @Ext_old AND SettingName = 'Station'

	SELECT @RemarkName = SettingValue FROM crmSetting WITH(NOLOCK) WHERE SettingID = @RemarkTitle AND SettingName = 'RemarkTitles'
	SELECT @Handler = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @HandlerID
	SELECT @Acknowledger = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @AcknowledgerID
	SELECT @Approver = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @ApproverID
	SELECT @Updater = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @ModifierID
	SELECT @ExtStation = SettingValue FROM crmSetting WITH(NOLOCK) WHERE SettingID = @Ext AND SettingName = 'Station'

	-- write log
	DECLARE @LogElement_old XML
	SELECT @LogElement_old = 				
					'<R>' + --SP Name
						'<CustID>'			+ ISNULL(CONVERT(VARCHAR(10),@CustID),'')				+ '</CustID>' +
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark_old),'')		+ '</Remark>' +
						'<RemarkName>'		+ ISNULL(CONVERT(VARCHAR(10),@RemarkName_old),'')		+ '</RemarkName>' +
						'<RelatedPICs>'		+ ISNULL(@RelatedPICs_old,'')							+ '</RelatedPICs>' +
						'<ExtID>'			+ ISNULL(CONVERT(VARCHAR(10),@Ext_old),'')				+ '</ExtID>' +
						'<Ext>'				+ ISNULL(@ExtStation_old,'')							+ '</Ext>' +
						'<HandlerID>'		+ ISNULL(CONVERT(VARCHAR(10),@HandlerID_old),'')		+ '</HandlerID>' +
						'<Handler>'			+ ISNULL(@Handler_old,'')								+ '</Handler>' +
						'<ApproverID>'		+ ISNULL(CONVERT(VARCHAR(10),@ApproverID_old),'')		+ '</ApproverID>' +
						'<Approver>'		+ ISNULL(@Approver_old,'')								+ '</Approver>' +
						'<AcknowledgerID>'	+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID_old),'')	+ '</AcknowledgerID>' +
						'<Acknowledger>'	+ ISNULL(@Acknowledger_old,'')							+ '</Acknowledger>' +
						'<Requester>'		+ ISNULL(@Requester_old,'')								+ '</Requester>' +
						'<ModifierID>'		+ ISNULL(CONVERT(VARCHAR(10),@ModifierID_old),'')		+ '</ModifierID>' +
						'<Modifier>'		+ ISNULL(@Updater_old,'')								+ '</Modifier>' +
						'<CreatorID>'		+ ISNULL(CONVERT(VARCHAR(10),@CreatorID_old),'')		+ '</CreatorID>' +
						'<Creator>'			+ ISNULL(@Creator,'')								+ '</Creator>' +
						'<LastUpdate>'		+ ISNULL(CONVERT(VARCHAR(20),@LastUpdate_old),'')		+ '</LastUpdate>' +
						'<CreatedDate>'		+ ISNULL(CONVERT(VARCHAR(20),@CreatedDate_old),'')		+ '</CreatedDate>' +
						'<IP>'				+ ISNULL(CONVERT(VARCHAR(15),@IP),'')					+ '</IP>' +
					'</R>' 
	DECLARE @LogElement XML
	SELECT @LogElement = 				
					'<R>' + --SP Name
						'<CustID>'			+ ISNULL(CONVERT(VARCHAR(10),@CustID),'')			+ '</CustID>' +
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')		+ '</Remark>' +
						'<RemarkName>'		+ ISNULL(CONVERT(VARCHAR(10),@RemarkName),'')		+ '</RemarkName>' +
						'<RelatedPICs>'		+ ISNULL(@RelatedPICs,'')							+ '</RelatedPICs>' +
						'<ExtID>'			+ ISNULL(CONVERT(VARCHAR(10),@Ext),'')				+ '</ExtID>' +
						'<Ext>'				+ ISNULL(@ExtStation,'')							+ '</Ext>' +
						'<HandlerID>'		+ ISNULL(CONVERT(VARCHAR(10),@HandlerID),'')		+ '</HandlerID>' +
						'<Handler>'			+ ISNULL(@Handler,'')								+ '</Handler>' +
						'<ApproverID>'		+ ISNULL(CONVERT(VARCHAR(10),@ApproverID),'')		+ '</ApproverID>' +
						'<Approver>'		+ ISNULL(@Approver,'')								+ '</Approver>' +
						'<AcknowledgerID>'	+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID),'')	+ '</AcknowledgerID>' +
						'<Acknowledger>'	+ ISNULL(@Acknowledger,'')							+ '</Acknowledger>' +
						'<Requester>'		+ ISNULL(@Requester,'')								+ '</Requester>' +
						'<ModifierID>'		+ ISNULL(CONVERT(VARCHAR(10),@ModifierID),'')		+ '</ModifierID>' +
						'<Modifier>'		+ ISNULL(@Updater,'')								+ '</Modifier>' +
						'<CreatorID>'		+ CASE WHEN @CreatorID_old IS NULL THEN ISNULL(CONVERT(VARCHAR(10),@ModifierID),'') ELSE ISNULL(CONVERT(VARCHAR(10),@CreatorID_old),'') END + '</CreatorID>' +
						'<Creator>'			+ CASE WHEN @CreatorID_old IS NULL THEN ISNULL(@Updater,'') ELSE ISNULL(@Creator,'') END + '</CreatorID>'+ 
						'<LastUpdate>'		+ ISNULL(CONVERT(VARCHAR(20),@NewUpdate),'')		+ '</LastUpdate>' +
						'<CreatedDate>'		+ CASE WHEN @CreatorID_old IS NULL THEN ISNULL(CONVERT(VARCHAR(10),@NewUpdate),'') ELSE ISNULL(CONVERT(VARCHAR(10),@CreatedDate_old),'') END + '</CreatedDate>' +
						'<IP>'				+ ISNULL(CONVERT(VARCHAR(15),@IP),'')					+ '</IP>' +
					'</R>' 

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @ModifierID, 
					@ActionID = 602, 
					@IP = @IP, 
					@OldValues = @LogElement_old,
					@NewValues = @LogElement
							
END	