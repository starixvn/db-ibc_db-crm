/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER  PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNewDel] 
	 @RemarkID INT
	,@UserID INT 
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
		- 20220325@Winfred: CRM - Delete special remarks renovation [RedmineId : #167941]
	
	Parameter's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
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
			,@CreatorID_old  INT 
			,@CreatedDate_old	 DATETIME
			,@LastUpdate_old	 DATETIME
			,@UserName NVARCHAR(50)
			,@Creator NVARCHAR(50)
			,@Handler NVARCHAR(50)
			,@Acknowledger NVARCHAR(50)
			,@Approver NVARCHAR(50)
			,@RemarkName NVARCHAR(100)
			,@ExtStation NVARCHAR(100)
			,@Updater NVARCHAR(50)
	
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
	,@CreatorID_old           	=   CreatorID  
	,@CreatedDate_old			=	CreatedDate
	,@LastUpdate_old			=	LastUpdate
	FROM  crmCustomerRemarkNew WITH(NOLOCK)
	WHERE RemarkID = @RemarkID
		
	DELETE crmCustomerRemarkNew WITH(UPDLOCK,ROWLOCK)      
	WHERE RemarkID = @RemarkID
	
	DELETE crmCustomerRemarkHistory WITH(UPDLOCK,ROWLOCK)      
	WHERE RemarkID = @RemarkID
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Delete remark unsuccessfuly.'
		RETURN
	END

	SELECT @UserName = UserName FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID_old
	SELECT @RemarkName = SettingValue FROM crmSetting WITH(NOLOCK) WHERE SettingID = @RemarkTitle_old AND SettingName = 'RemarkTitles'
	SELECT @Creator = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @CreatorID_old
	SELECT @Handler = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @HandlerID_old
	SELECT @Acknowledger = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @AcknowledgerID_old
	SELECT @Approver = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @ApproverID_old
	SELECT @Updater = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @ModifierID_old
	SELECT @ExtStation = SettingValue FROM crmSetting WITH(NOLOCK) WHERE SettingID = @Ext_old AND SettingName = 'Station'
	
	-- write log
	DECLARE @LogElement_old XML
	SELECT @LogElement_old = 				
					'<R>' + --SP Name
						'<CustID>'			+ ISNULL(CONVERT(VARCHAR(10),@CustID_old),'')			+ '</CustID>' +
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark_old),'')		+ '</Remark>' +
						'<RemarkName>'		+ ISNULL(CONVERT(VARCHAR(10),@RemarkName),'')			+ '</RemarkName>' +
						'<RelatedPICs>'		+ ISNULL(@RelatedPICs_old,'')							+ '</RelatedPICs>' +
						'<ExtID>'			+ ISNULL(CONVERT(VARCHAR(10),@Ext_old),'')				+ '</ExtID>' +
						'<Ext>'				+ ISNULL(@ExtStation,'')								+ '</Ext>' +
						'<HandlerID>'		+ ISNULL(CONVERT(VARCHAR(10),@HandlerID_old),'')		+ '</HandlerID>' +
						'<Handler>'			+ ISNULL(@Handler,'')									+ '</Handler>' +
						'<ApproverID>'		+ ISNULL(CONVERT(VARCHAR(10),@ApproverID_old),'')		+ '</ApproverID>' +
						'<Approver>'		+ ISNULL(@Approver,'')									+ '</Approver>' +
						'<AcknowledgerID>'	+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID_old),'')	+ '</AcknowledgerID>' +
						'<Acknowledger>'	+ ISNULL(@Acknowledger,'')								+ '</Acknowledger>' +
						'<Requester>'		+ ISNULL(@Requester_old,'')								+ '</Requester>' +
						'<ModifierID>'		+ ISNULL(CONVERT(VARCHAR(10),@ModifierID_old),'')		+ '</ModifierID>' +
						'<Modifier>'		+ ISNULL(@Updater,'')									+ '</Modifier>' +
						'<CreatorID>'		+ ISNULL(CONVERT(VARCHAR(10),@CreatorID_old),'')		+ '</CreatorID>' +
						'<Creator>'			+ ISNULL(@Creator,'')								+ '</Creator>' +
						'<LastUpdate>'		+ ISNULL(CONVERT(VARCHAR(20),@LastUpdate_old),'')		+ '</LastUpdate>' +
						'<CreatedDate>'		+ ISNULL(CONVERT(VARCHAR(20),@CreatedDate_old),'')		+ '</CreatedDate>' +
						'<IP>'				+ ISNULL(CONVERT(VARCHAR(15),@IP),'')					+ '</IP>' +
					'</R>' 

	DECLARE @LogElement XML
	SELECT @LogElement = '<R>' + '<CustID></CustID>' +
								'<Remark></Remark>' +
								'<RemarkName></RemarkName>' +
								'<RelatedPICs></RelatedPICs>' +
								'<ExtID></ExtID>' +
								'<Ext></Ext>' +
								'<HandlerID></HandlerID>' +
								'<Handler></Handler>' +
								'<ApproverID></ApproverID>' +
								'<Approver></Approver>' +
								'<AcknowledgerID></AcknowledgerID>' +
								'<Acknowledger>	</Acknowledger>' +
								'<Requester></Requester>' +
								'<ModifierID></ModifierID>' +
								'<Modifier></Modifier>' +
								'<CreatorID></CreatorID>' +
								'<Creator></Creator>' +
								'<LastUpdate></LastUpdate>' +
								'<CreatedDate></CreatedDate>' +
								'<IP></IP>'  + '</R>'

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID_old, 
					@UserID = @UserID, 
					@ActionID = 603, 
					@IP = @IP, 
					@OldValues = @LogElement_old,
					@NewValues = @LogElement
							
END	
