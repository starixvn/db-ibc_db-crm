ALTER PROCEDURE Acc_CRM_RedemptionUpd
	@ID				INT,
	@Subject		NVARCHAR(200),
    @ClaimTime		DATETIME,
    @Remark			NTEXT,
    @StatusID		INT,
	@CurrencyID		INT,
	@Amount			DECIMAL(18,2),
	@DoneBy			NVARCHAR(300),
    @UserID			INT,
	@IP				VARCHAR(15),
	@ErrCode		INT				= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000)	= '' OUTPUT
AS


/*
Created: 20140207@Dom
Task : Update redemption log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	- 20141118@Dom: Add currency and amount
Param's Explanation:
*/

	DECLARE @Subject_Old	NVARCHAR(200),
		@ClaimTime_Old		DATETIME,
		@Remark_Old			NVARCHAR(MAX),
		@StatusID_Old		INT,
		@CustID				INT,
		@CurrencyID_Old		INT,
		@Amount_Old			DECIMAL(18,2),
		@DoneBy_Old			NVARCHAR(300)

    
	SELECT @Subject_Old	= Subject,
		@ClaimTime_Old	= ClaimTime,     
		@Remark_Old		= Remark,
		@StatusID_Old	= StatusID,
		@CustID			= CustID,
		@CurrencyID_Old	= CurrencyID,
		@Amount_Old		= Amount,
		@DoneBy_Old		= DoneBy

	FROM crmRedemption(NOLOCK)
	WHERE ID = @ID

	UPDATE crmRedemption
	SET Subject		= @Subject,
		ClaimTime	= @ClaimTime,
		StatusID	= @StatusID,
		Remark		= @Remark,
		CurrencyID	= @CurrencyID,
		Amount		= @Amount,
		DoneBy		= @DoneBy
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
						'<Subject>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Subject_Old),'')	+ '</Subject>'		+
						'<ClaimTime>'		+ ISNULL(CONVERT(VARCHAR(20),@ClaimTime_Old),'')	+ '</ClaimTime>'	+
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark_Old),'')	+ '</Remark>'		+
						'<StatusID>'		+ ISNULL(CONVERT(VARCHAR(10),@StatusID_Old),'')		+ '</StatusID>'		+
						'<CurrencyID>'		+ ISNULL(CONVERT(VARCHAR(10),@CurrencyID_Old),'')	+ '</CurrencyID>'	+
						'<Amount>'			+ ISNULL(CONVERT(VARCHAR(30),@Amount_Old),'')		+ '</Amount>'		+
						'<DoneBy>'			+ ISNULL([dbo].[f_EncodeXMLValue](@DoneBy_Old),'')		+ '</DoneBy>' +
					'</Acc_CRM_RedemptionUpd>'
	SELECT @NewValues = 				
					'<Acc_CRM_RedemptionUpd>' + --SP Name
						'<Subject>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Subject),'')		+ '</Subject>'		+
						'<ClaimTime>'		+ ISNULL(CONVERT(VARCHAR(20),@ClaimTime),'')		+ '</ClaimTime>'	+
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')		+ '</Remark>'		+
						'<StatusID>'		+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')			+ '</StatusID>'		+
						'<CurrencyID>'		+ ISNULL(CONVERT(VARCHAR(10),@CurrencyID),'')		+ '</CurrencyID>'	+
						'<Amount>'			+ ISNULL(CONVERT(VARCHAR(30),@Amount),'')			+ '</Amount>'		+
						'<DoneBy>'			+ ISNULL([dbo].[f_EncodeXMLValue](@DoneBy),'')		+ '</DoneBy>' +
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

