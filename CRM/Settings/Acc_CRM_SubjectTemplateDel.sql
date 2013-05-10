ALTER PROCEDURE [dbo].[Acc_CRM_SubjectTemplateDel]
(
	@TemplateID INT,	
	@errCode INT = 0 OUTPUT,
	@errMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
	Created: 20120227@Lukas
	Task : delete subject template
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
	SET IsActive = 0
	WHERE TemplateID = @TemplateID

	IF @@ERROR <> 0
	BEGIN
		SELECT @errCode = 100,
				@errMsg = 'Delete subject template is not successful.'
	END

END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SubjectTemplateDel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SubjectTemplateDel] TO [vnteam] 