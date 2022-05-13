/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_CustomerRemarkNewIns] 
	 @CustID	INT = Null
	,@Remark NVARCHAR(MAX) = Null
	,@RemarkTitle INT = Null
	,@RelatedPICs  VARCHAR(1000)  = Null
	,@Ext	INT = Null
	,@HandlerID INT = Null
	,@ApproverID INT = Null
	,@AcknowledgerID INT = Null
	,@Requester NVARCHAR(500) = Null
	,@ModifierID INT = Null
	,@CreatorID INT = Null
	,@IP VARCHAR(15) = Null
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
	
	DECLARE @NewUpdate DATETIME, @UserName NVARCHAR(50), @Creator NVARCHAR(50),
			@Handler NVARCHAR(50), @Acknowledger NVARCHAR(50), @Approver NVARCHAR(50), 
			@RemarkName NVARCHAR(100), @ExtStation NVARCHAR(100), @Updater NVARCHAR(50)
	SET @NewUpdate = GETDATE()
		
	IF ISNULL(@Remark, '') = '' OR	ISNULL(@RemarkTitle, 0) = 0 
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Incorrect Data.';
		RETURN;
	END;
	
	IF IsNull(@RelatedPICs,'')  <> '' AND EXISTS (SELECT TOP 1 1 FROM STRING_SPLIT(@RelatedPICs,',') 
					WHERE  value <> '' AND NOT EXISTS (SELECT 1 FROM crmPIC WITH(NOLOCK) 
					WHERE PicID = value) )
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
		,ModifierID
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
		,@ModifierID
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
	
	SELECT @UserName = UserName FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID
	SELECT @RemarkName = SettingValue FROM crmSetting WITH(NOLOCK) WHERE SettingID = @RemarkTitle AND SettingName = 'RemarkTitles'
	SELECT @Creator = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @CreatorID
	SELECT @Handler = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @HandlerID
	SELECT @Acknowledger = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @AcknowledgerID
	SELECT @Approver = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @ApproverID
	SELECT @Updater = UserName FROM DBACC.bodb02.dbo.Custinfo WITH(NOLOCK) WHERE CustID = @ModifierID
	SELECT @ExtStation = SettingValue FROM crmSetting WITH(NOLOCK) WHERE SettingID = @Ext AND SettingName = 'Station'

	-- write log
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
						'<CreatorID>'		+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')		+ '</CreatorID>' +
						'<Creator>'			+ ISNULL(@Creator,'')								+ '</Creator>' +
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