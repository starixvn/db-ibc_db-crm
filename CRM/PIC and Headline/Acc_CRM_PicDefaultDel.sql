/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicDefaultDel]
	@HeadlineID		INT,
	@UserID			INT,
	@LoginIP        VARCHAR(20) ='',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20200717@Malcolm
Task :  Get default PICs of a headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200717@Malcolm: remove default PICs from a headline [Redmine: #137144]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @HeadlineName VARCHAR(20), @NewValues XML = NULL


	SELECT @HeadlineName = Username FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid = @HeadlineID

	SELECT @NewValues =	(SELECT  d.PicID		AS '@PicID',
								 P.Username		AS '@PicName'
						FROM dbo.crmPICDefault d WITH(NOLOCK)
							INNER JOIN dbo.crmPIC p WITH(NOLOCK)  ON d.PicID = p.PicID
						WHERE HeadlineID = @HeadlineID
						FOR XML PATH('PIC'),ROOT('Acc_CRM_PicDefaultDel'))

	BEGIN TRY
		DELETE dbo.crmPICDefault
		WHERE HeadlineID = @HeadlineID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH	

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustId = @HeadlineID,
			@ActionID = 908,
			@IP = @LoginIP,
			@NewValues = @NewValues

END
GO
