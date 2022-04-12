/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNewIns] 
	 @CustID INT 
	,@Remark NVARCHAR(MAX) 
	,@RemarkTitle INT 
	,@RelatedPICs  VARCHAR(1000) 
	,@Ext	INT 
	,@HandlerID INT 
	,@ApproverID INT 
	,@AcknowledgerID INT 
	,@Requester NVARCHAR(500) 
	,@UpdaterID INT 
	,@CreatorID INT 
	,@IP VARCHAR(15)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = ''	OUTPUT
AS
/*
	Created: 20220325@Winfred
	Task : CRM - insert special remarks renovation into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20220325@Winfred: CRM - insert special remarks renovation [RedmineId : #167941]
	
	Parameter's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @NewUpdate DATETIME
	SET @NewUpdate = GETDATE()
		
	IF ISNULL(@Remark, '') = '' OR	ISNULL(@RemarkTitle, 0) = 0 
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Incorrect Data.';
		RETURN;
	END;
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.strSplit(@RelatedPICs,',') 
					WHERE NOT EXISTS (SELECT 1 FROM crmPIC WITH(NOLOCK) 
					WHERE PicID = SettingID) )
	BEGIN
		SELECT	@ErrCode = 101
			,	@ErrMsg = 'PIC does not exist in IBC system.';
		RETURN;
	END;
	
	-- Sync Data From main 
	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		EXEC Acc_CRM_CopyCustomerInformation
			@CustID		= @CustID,
			@UserID		= @CreatorID,
			@IP			= @IP,
			@ErrCode	= @ErrCode OUTPUT,
			@ErrMsg		= @ErrMsg OUTPUT

			IF @ErrCode <> 0
				RETURN
	END
	
	INSERT INTO crmCustomerRemarkNew
	(
		 CustID
		,Remark
		,RemarkTitle
		,RelatedPICs
		,Ext
		,HandlerID
		,ApproverID
		,AcknowledgerID
		,Requester
		,UpdaterID
		,LastUpdate
		,CreatorID
		,CreatedDate
	)
	VALUES
	(
		@CustID
		,@Remark
		,@RemarkTitle
		,@RelatedPICs
		,@Ext
		,@HandlerID
		,@ApproverID
		,@AcknowledgerID
		,@Requester
		,@UpdaterID
		,@NewUpdate
		,@CreatorID
		,@NewUpdate
	)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'create new remark unsuccessfuly.'
		RETURN
	END
	
	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<R>' + --SP Name
						'<CustID>'		+ ISNULL(CONVERT(VARCHAR(10),@CustID),'')			+ '</CustID>' +
						'<Remark>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')		+ '</Remark>' +
						'<RemarkTitle>'	+ ISNULL(CONVERT(VARCHAR(10),@RemarkTitle),'')		+ '</RemarkTitle>' +
						'<RelatedPICs>'	+ ISNULL(@RelatedPICs,'')							+ '</RelatedPICs>' +
						'<Ext>'			+ ISNULL(CONVERT(VARCHAR(10),@Ext),'')				+ '</Ext>' +
						'<HandlerID>'	+ ISNULL(CONVERT(VARCHAR(10),@HandlerID),'')		+ '</HandlerID>' +
						'<ApproverID>'	+ ISNULL(CONVERT(VARCHAR(10),@ApproverID),'')		+ '</ApproverID>' +
						'<AcknowledgerID>'+ ISNULL(CONVERT(VARCHAR(10),@AcknowledgerID),'')	+ '</AcknowledgerID>' +
						'<Requester>'	+ ISNULL(CONVERT(VARCHAR(10),@Requester),'')		+ '</Requester>' +
						'<UpdaterID>'	+ ISNULL(CONVERT(VARCHAR(10),@UpdaterID),'')		+ '</UpdaterID>' +
						'<CreatorID>'	+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')		+ '</CreatorID>' +
						'<LastUpdate>'		+ ISNULL(CONVERT(VARCHAR(20),@NewUpdate),'')		+ '</LastUpdate>' +
						'<CreatedDate>'		+ ISNULL(CONVERT(VARCHAR(20),@NewUpdate),'')		+ '</CreatedDate>' +
					'</R>' 
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @CreatorID, 
					@ActionID = 601, 
					@IP = @IP, 
					@NewValues = @LogElement
							
END	