
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_RedemptionUpd    Script Date: 3/26/2014 6:06:08 PM ******/
CREATE PROCEDURE Acc_CRM_RedemptionUpd
	@ID			INT,
	@Subject	NVARCHAR(200),
    @ClaimTime	DATETIME,
    @Remark		NTEXT,
    @StatusID	INT,
    @UserID		INT,
	@IP					VARCHAR(15),
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT
AS


/*
Created: 20140207@Dom
Task : Update redemption log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
*/

	DECLARE @Subject_Old	NVARCHAR(200),
		@ClaimTime_Old		DATETIME,
		@Remark_Old			NVARCHAR(MAX),
		@StatusID_Old		INT,
		@CustID				INT
    
	SELECT @Subject_Old	= Subject,
		@ClaimTime_Old	= ClaimTime,     
		@Remark_Old		= Remark,
		@StatusID_Old	= StatusID,
		@CustID			= CustID
	FROM crmRedemption(NOLOCK)
	WHERE ID = @ID

	UPDATE crmRedemption
	SET Subject = @Subject,
		ClaimTime = @ClaimTime,
		StatusID = @StatusID,
		Remark = @Remark
	WHERE ID = @ID

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'updated redemption unsuccessfuly.'
		RETURN
	END
	
-- write log
	DECLARE @NewValues XML,@OldValues XML

	SELECT @OldValues = 				
					'<Acc_CRM_RedemptionUpd>' + --SP Name
						'<Subject>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Subject_Old),'')	+ '</Subject>' +
						'<ClaimTime>'		+ ISNULL(CONVERT(VARCHAR(20),@ClaimTime_Old),'')	+ '</ClaimTime>' +
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark_Old),'')	+ '</Remark>' +
						'<StatusID>'		+ ISNULL(CONVERT(VARCHAR(10),@StatusID_Old),'')		+ '</StatusID>' +
					'</Acc_CRM_RedemptionUpd>'
	SELECT @NewValues = 				
					'<Acc_CRM_RedemptionUpd>' + --SP Name
						'<Subject>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Subject),'')	+ '</Subject>' +
						'<ClaimTime>'		+ ISNULL(CONVERT(VARCHAR(20),@ClaimTime),'')	+ '</ClaimTime>' +
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')	+ '</Remark>' +
						'<StatusID>'		+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')		+ '</StatusID>' +
					'</Acc_CRM_RedemptionUpd>'

	EXEC [dbo].[WriteLog_UserLog_crmLogRedemption]
					@RedemptionID = @ID,
					@CustID = @CustID,
					@UserID = @UserID,
					@ActionID = 501,
					@IP = @IP,
					@NewValues = @NewValues,
					@OldValues = @OldValues
					

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_RedemptionUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_RedemptionUpd] TO [vnteam]
GO 
