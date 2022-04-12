/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER  PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNew_Del] 
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
	
	-- write log
	DECLARE @LogElement_old XML
	SELECT @LogElement_old = 				
					'<Acc_CRM_CustomerRemarkNew_Del>' + --SP Name
						'<CustID>'		+ ISNULL(CONVERT(VARCHAR(10),@CustID_old),'')			+ '</CustID>' +
						'<Remark>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Remark_old),'')		+ '</Remark>' +
						'<RemarkTitle>'	+ ISNULL(CONVERT(VARCHAR(10),@RemarkTitle_old),'')		+ '</RemarkTitle>' +
						'<RelatedPICs>'	+ ISNULL(@RelatedPICs_old,'')							+ '</RelatedPICs>' +
						'<HandlerID>'		+ ISNULL(CONVERT(VARCHAR(10),@HandlerID_old),'')	+ '</HandlerID>' +
						'<ApproverID>'	+ ISNULL(CONVERT(VARCHAR(10),@ApproverID_old),'')		+ '</ApproverID>' +
						'<AcknowledgerID>'+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID_old),'')	+ '</AcknowledgerID>' +
						'<Requester>'	+ ISNULL(CONVERT(VARCHAR(10),@Requester_old),'')		+ '</Requester>' +
						'<UpdaterID>'		+ ISNULL(CONVERT(VARCHAR(10),@UpdaterID_old),'')	+ '</UpdaterID>' +
						'<IP>'		+ ISNULL(CONVERT(VARCHAR(15),@IP),'')					+ '</IP>' +
					'</Acc_CRM_CustomerRemarkNew_Del>' 

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @UserID, 
					@UserID = @UserID, 
					@ActionID = 603, 
					@IP = @IP, 
					@OldValues = @LogElement_old,
					@NewValues = ''
							
END	