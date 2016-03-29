SET QUOTED_IDENTIFIER ON; 
GO
SET ANSI_NULLS ON; 
GO

ALTER PROCEDURE	dbo.Acc_CRM_SubjectTemplateDel (
					@TemplateID		INT
				,	@isActive		BIT
				,	@errCode		INT				= 0		OUTPUT
				,	@errMsg			NVARCHAR(200)	= ''	OUTPUT
				)
AS
/*
	Created:	20120227@Lukas
	Task:		delete subject template
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20120316@Elodie:	change DB06 to DB052 
		- 20160301@Billy:	Change status of a setting value (Active/Inactive) - [Redmine: #53173]

	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE	@OldIsActive		BIT;

	SELECT	@OldIsActive = cst.IsActive
	FROM	dbo.crmSubjectTemplate AS cst WITH (NOLOCK)
	WHERE	cst.templateID = @TemplateID;

	IF	@OldIsActive IS NULL	
	BEGIN
		SELECT	@errCode	= 100
			,	@errMsg		= 'Setting does not exist.';
		RETURN;
	END;

	IF	@OldIsActive = @isActive
		RETURN;

	-- Update isActive value
	UPDATE	dbo.crmSubjectTemplate WITH (ROWLOCK, UPDLOCK)
	SET		IsActive = @isActive
	WHERE	TemplateID = @TemplateID;

	IF @@ERROR <> 0
	BEGIN
		SELECT	@errCode = 100
			,	@errMsg = CASE @isActive WHEN 0	THEN 'Deactivate subject template unsuccessfully.'
			  									ELSE 'Active subject template unsuccessfully.'
						  END;
		RETURN;
	END;
END;

GO
GRANT EXECUTE ON dbo.Acc_CRM_SubjectTemplateDel TO [bodbAdminNet];
GO
GRANT VIEW DEFINITION ON dbo.Acc_CRM_SubjectTemplateDel TO [vnteam]; 