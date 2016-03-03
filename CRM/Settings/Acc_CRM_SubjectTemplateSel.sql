ALTER PROCEDURE	dbo.Acc_CRM_SubjectTemplateSel (
					@TemplateID		INT		= 0
				)
AS
/*
	Created:	20120224@Lukas
	Task:		Get subject template
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20120316@Elodie:	change DB06 to DB052 
		- 20160301@Billy:	Change status of a setting value (Active/Inactive) - [Redmine: #53173]

	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	cst.templateID
		,	cst.subject
		,	cst.IsActive
	FROM	dbo.crmSubjectTemplate AS cst WITH (NOLOCK)
	WHERE	cst.templateID = CASE WHEN @TemplateID = 0	THEN cst.templateID
														ELSE @TemplateID END
	ORDER BY cst.IsActive DESC;
END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_SubjectTemplateSel TO [bodbAdminNet];
GO
GRANT VIEW DEFINITION ON dbo.Acc_CRM_SubjectTemplateSel TO [vnteam]; 