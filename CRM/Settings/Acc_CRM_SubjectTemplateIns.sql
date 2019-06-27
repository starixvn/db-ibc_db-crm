/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_SubjectTemplateIns]
(	
	@subject NVARCHAR(200) = '',
	@errCode INT = 0 OUTPUT,
	@errMsg NVARCHAR(200) = '' OUTPUT,
	@UserRole		INT
)
AS
/*
	Created: 20120224@Lukas
	Task : insert new subject template
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20120316@Elodie: change DB06 to DB052 
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	SELECT	@errCode = 0,
			@errMsg = ''	

	INSERT INTO crmSubjectTemplate (subject, IsActive,SiteOffer) VALUES (@subject, 1,@UserRole)		

	IF @@ERROR <> 0
	BEGIN
		SELECT @errCode = 100,
				@errMsg = 'Insert subject template is not successful.'
	END

END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SubjectTemplateIns] TO [bodbAdminNet]
GO
