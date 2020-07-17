/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_HeadlineUpd]
	@CustID		INT = 0,
	@Username   VARCHAR(30) = '',
	@Case		INT = 0,
	@LoginIP	VARCHAR(20)='',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000) = '' OUTPUT,
	@UserID		INT
AS
/*
Created: 20200717@Malcolm
Task : 
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200717@Malcolm:  Integrate Credit Term & Staff/Boss Management  [Redmine: #137144]
	Param's Explanation:
		@Case = 0 : No change
		      = 1 : remove PICs which manage this Customer AND assign PIC (default PICs of new headline) to this customer
			  = 2 :
			  = 3 :
			  = 4 :
		
		
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @GroupId INT, @HeadlineId INT

	SELECT @CustID = ISNULL(@CustID,0), @Username = ISNULL(@Username,'')

	IF @CustID = 0
	BEGIN
		SELECT @CustID = CustId FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE username = @Username
	END

	SELECT @GroupId = ISNULL(GroupId,0) FROM bodb02.dbo.custAccount WITH(NOLOCK) WHERE custid = @CustID

	SELECT @HeadlineId = CustId FROM bodb02.dbo.CustGroupHeadline WITH(NOLOCK) WHERE GroupID = @GroupId

	IF @Case = 0
		RETURN

	IF @Case IN (3,4)
	BEGIN
		UPDATE dbo.crmPICHeadline
		SET HeadlineID = @CustID
		WHERE EXISTS (
			SELECT 1 
			FROM bodb02.dbo.custAccount
			WHERE groupID = @GroupId AND custid = HeadlineID)

		UPDATE dbo.crmPICDefault
		SET HeadlineID = @CustID
		WHERE EXISTS (
			SELECT 1 
			FROM bodb02.dbo.custAccount
			WHERE groupID = @GroupId AND custid = HeadlineID)
	END

	IF @Case IN (1,4)
	BEGIN
		DELETE dbo.crmPicManagement
		WHERE CustID = @CustID

		INSERT INTO dbo.crmPicManagement
		(
			CustID,
			PicID
		)
		SELECT 
			@CustID, 
			PicID
		FROM dbo.crmPICDefault WITH(NOLOCK)
		WHERE HeadlineID = @HeadlineId
	END

	IF @Case = 2
	BEGIN
		DELETE dbo.crmPicManagement
		WHERE CustID = @CustID

		DELETE dbo.crmPICHeadline
		WHERE HeadlineID = @CustID
	END

END