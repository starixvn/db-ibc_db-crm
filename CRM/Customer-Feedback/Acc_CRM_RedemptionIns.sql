
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_RedemptionIns    Script Date: 3/26/2014 6:06:08 PM ******/

CREATE PROCEDURE Acc_CRM_RedemptionIns
    @Subject	NVARCHAR(200),
    @ClaimTime	DATETIME,
    @Remark		NTEXT,
    @StatusID	INT,
    @CustID		INT,
    @UserID		INT,
	@IP			VARCHAR(15),
	@ErrCode	INT				= 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000)	= '' OUTPUT
AS

/*
Created: 20140207@Dom
Task : Insert new redemption log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
*/

IF NOT EXISTS(SELECT 1 FROM crmCustomer(NOLOCK) WHERE CustID = @CustID)
BEGIN
	EXEC Acc_CRM_CopyCustomerInformation
		@CustID		= @CustID,
		@UserID		= @UserID,
		@IP			= @IP,
		@ErrCode	= @ErrCode OUTPUT,
		@ErrMsg		= @ErrMsg OUTPUT

		IF @ErrCode <> 0 RETURN;
END

DECLARE @RedemptionID INT

INSERT INTO [dbo].[crmRedemption]
           ([Subject]
           ,[ClaimTime]
           ,[Remark]
           ,[StatusID]
           ,[CustID]
           ,[CreateDate]
           ,[Creator])
SELECT      @Subject,
			@ClaimTime,	
			@Remark,		
			@StatusID,	
			@CustID,	
			GETDATE(), 
			@UserID
			
IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'Insert feedback unsuccessfuly.'
		RETURN
	END
	
SELECT @RedemptionID = @@identity
	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_RedemptionIns>' + --SP Name
						'<Subject>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Subject),'')	+ '</Subject>' +
						'<ClaimTime>'		+ ISNULL(CONVERT(VARCHAR(20),@ClaimTime),'')	+ '</ClaimTime>' +
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')	+ '</Remark>' +
						'<StatusID>'		+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')		+ '</StatusID>' +
						'<CustID>'			+ ISNULL(CONVERT(VARCHAR(10),@CustID),'')		+ '</CustID>' +
					'</Acc_CRM_RedemptionIns>'


	EXEC [dbo].[WriteLog_UserLog_crmLogRedemption]
					@RedemptionID = @RedemptionID,
					@CustID = @CustID,
					@UserID = @UserID,
					@ActionID = 500,
					@IP = @IP,
					@NewValues = @LogElement



GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_RedemptionIns] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_RedemptionIns] TO [vnteam]
GO 
