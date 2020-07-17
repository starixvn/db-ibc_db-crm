/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicDefaultDel]
	@HeadlineID		INT,
	@UserID			INT,
	@LoginIP        VARCHAR(20) =''
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

	DECLARE @HeadlineName VARCHAR(20), @NewValues XML

	SELECT @HeadlineName = Username FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid = @HeadlineID

	SELECT @NewValues =	(SELECT  @HeadlineID	AS '@HeadlineID',
								 @HeadlineName	AS '@HeadlineName',
								 d.PicID		AS '@PicID',
								 P.Username		AS '@PicName'
						FROM dbo.crmPICDefault d WITH(NOLOCK)
							INNER JOIN dbo.crmPIC p WITH(NOLOCK)  ON d.PicID = p.PicID
						WHERE HeadlineID = @HeadlineID
						FOR XML PATH('DefaultPIC'),ROOT('Acc_CRM_PicDefaultDel'))

	DELETE dbo.crmPICDefault
	WHERE HeadlineID = @HeadlineID

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
				@UserID = @UserID,
				@ActionID = 910,
				@IP = @LoginIP,
				@NewValues = @NewValues

END
GO
