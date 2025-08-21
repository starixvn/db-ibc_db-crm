/*<info serverAlias="DBBOT-bodb_Chatbot" executers="wsv_nap" viewers="" isFunction="0"></info>*/
USE [bodb_ChatBot]
GO

CREATE PROCEDURE [dbo].[Acc_CRM_SMAFeedbackInfoUpd] (
	@CustID			INT,
	@CreatedDate	SMALLDATETIME,
	@FunctionID		INT,
	@Comment		NVARCHAR(4000),
	@ReviewStatusID	INT,
	@Discussion		NVARCHAR(4000),
	@ErrCode		INT	= 0				OUTPUT,
	@ErrMsg			NVARCHAR(4000) = ''	OUTPUT,
	@LoginIP		VARCHAR(45) = ''
)
AS
/*
	Created: 20250317@Virgil
	Task: CRM - Manage SMA Feedback in effective way [Redmine #196012]
	DB: DBBOT-bodb_Chatbot

	Revisions:
		- 20250317@Virgil: Initial SP [Redmine #196012]
		- 20250807@Dave: CRM - Manage SMA Feedback in effective way - Add Rating [Redmine #235385]

	Param's Explanation:
		- @FunctionID = NULL - Function Name: N/A
*/
BEGIN
	SET NOCOUNT ON;

	SELECT @ErrCode	= 0,
			@ErrMsg = '';

	SET @FunctionID = ISNULL(@FunctionID,0);
	DECLARE @StartOfDay SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, @CreatedDate), 0);

	IF NOT EXISTS (SELECT TOP(1) 1 
					FROM CustFeedback WITH (NOLOCK) 
					WHERE custid = @CustID 
						AND (
							(FuncID = @FunctionID)
							OR (FuncID IS NULL AND @FunctionID = 0)
						)
						AND CreatedDate = @CreatedDate)
	BEGIN
		SELECT	@ErrCode = 100 ,
				@ErrMsg = 'SMA Feedback does not exist.';

		RETURN;
	END;

	--- Update SMA Feedback
	UPDATE CustFeedback WITH (ROWLOCK, UPDLOCK)
	SET	ReviewStatusID = @ReviewStatusID,
		Discussion = @Discussion
	WHERE custid = @CustID 
		AND (
			(FuncID = @FunctionID)
			OR (FuncID IS NULL AND @FunctionID = 0)
		)
		AND CreatedDate >= @StartOfDay
		AND CreatedDate <= @CreatedDate
		AND Comment = @Comment
		AND LEN(Comment) = LEN(@Comment);
	
	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 101,
				@ErrMsg = 'Updated SMA Feedback unsuccessfuly!';
	END;

END;
GO