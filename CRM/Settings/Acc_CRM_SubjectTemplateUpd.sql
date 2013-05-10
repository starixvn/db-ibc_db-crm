 ALTER PROCEDURE [dbo].[Acc_CRM_SubjectTemplateUpd]
(
	@TemplateID INT,
	@subject NVARCHAR(200) = '',
	@errCode INT = 0 OUTPUT,
	@errMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
	Created: 20120224@Lukas
	Task : update subject template
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		-20120316@Elodie: change DB06 to DB052
	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	SELECT	@errCode = 0,
			@errMsg = ''	

	UPDATE crmSubjectTemplate WITH(ROWLOCK,UPDLOCK)
	SET subject = @subject
	WHERE TemplateID = @TemplateID

	IF @@ERROR <> 0
	BEGIN
		SELECT @errCode = 100,
				@errMsg = 'Update subject template is not successful.'
	END
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SubjectTemplateUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SubjectTemplateUpd] TO [vnteam]