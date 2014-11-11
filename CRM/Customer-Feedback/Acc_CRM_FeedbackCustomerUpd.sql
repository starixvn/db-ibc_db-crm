ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackCustomerUpd]
(
	@UserID				INT,
	@FeedbackID			INT,
	@RelatedCustID		NVARCHAR(MAX)	= NULL,	
	@IP					VARCHAR(15),
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
	Created: Lukas
	Date: 20101023
	Task : update feedback related
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas: support multiple feedback related customer
		- 20120323@Elodie: change DB06 to DB052,
						   check condition that feedback related customer must be different to customer of feedback,
						   check duplicate related customer.
		- 20120418@Elodie: remove all related customers of feedback if @RelatedCustID parameter is empty.				   
						   change default value of @RelatedCustID param to NULL value
		- 20140303@Dom: Modify for new structure
	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	IF @RelatedCustID = ''
	BEGIN
		DELETE FROM crmFeedbackCustomer WITH(ROWLOCK,UPDLOCK)
		WHERE FeedbackID = @FeedbackID			
			AND IsRelated = 1
		IF @@ERROR <> 0
		BEGIN
			SELECT	@ErrCode = 100,
					@ErrMsg = 'Update Feedback related customer unsuccessfully.'
			RETURN
		END		
	END
	ELSE -- @RelatedCustID <> ''
	BEGIN
		DECLARE @relatedCustomer TABLE(CustID INT)

		INSERT INTO @relatedCustomer
				SELECT CONVERT(INT,val)
				FROM [dbo].[f_split](@RelatedCustID,',')

		IF EXISTS (SELECT TOP 1 1 FROM @relatedCustomer )
		BEGIN
			DELETE FROM crmFeedbackCustomer WITH(ROWLOCK,UPDLOCK)
			WHERE FeedbackID = @FeedbackID
				AND CustID NOT IN (SELECT CustID FROM @relatedCustomer)
				AND IsRelated = 1
			IF @@ERROR <> 0
			BEGIN
				SELECT	@ErrCode = 100,
						@ErrMsg = 'Update Feedback related customer unsuccessfully.'
				RETURN
			END

			DELETE FROM @relatedCustomer
			WHERE custID IN (	SELECT custID 
								FROM crmFeedbackCustomer WITH(NOLOCK)
								WHERE FeedbackID = @FeedbackID AND IsRelated = 1)		
				
			DECLARE @CustID int

			SELECT @CustID = CustID 
			FROM crmFeedbackCustomer WITH(NOLOCK)
			WHERE FeedbackID = @FeedbackID AND IsRelated = 0

			INSERT INTO crmFeedbackCustomer(FeedbackID, Custid, IsRelated)
								SELECT DISTINCT @FeedbackID, custID, 1
								FROM @relatedCustomer 
								where CustID <> @CustID
			IF @@ERROR <> 0
			BEGIN
				SELECT	@ErrCode = 101,
						@ErrMsg = 'Update Feedback related customer unsuccessfully.'
				RETURN
			END
		END
	END
	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_FeedbackCustomerUpd>' + --SP Name						
						'<RelatedCustID>'			+ ISNULL(@RelatedCustID,'')	+ '</RelatedCustID>' +						
					'</Acc_CRM_FeedbackCustomerUpd>'
				

	EXEC [dbo].[WriteLog_UserLog_crmLogFeedback]
					@UserID = @UserID, 
					@FeedbackID = @FeedbackID,
					@CustID = 0,  
					@ActionID = 401, 
					@IP = @IP, 
					@Description = '', 
					@Solution = '',
					@Review =  '',
					@NewValues = @LogElement
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackCustomerUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackCustomerUpd] TO [vnteam]
GO 
