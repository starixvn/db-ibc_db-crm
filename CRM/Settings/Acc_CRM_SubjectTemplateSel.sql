ALTER PROCEDURE [dbo].[Acc_CRM_SubjectTemplateSel]
(
	@TemplateID INT = 0
)
AS
/*
	Created: 20120224@Lukas
	Task : Get subject template
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		-20120316@Elodie: change DB06 to DB052 
	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	SELECT templateID, subject
	FROM crmSubjectTemplate WITH(NOLOCK)
	WHERE templateID = CASE WHEN @TemplateID = 0 THEN TemplateID ELSE @TemplateID END
		AND IsActive = 1

END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SubjectTemplateSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SubjectTemplateSel] TO [vnteam] 