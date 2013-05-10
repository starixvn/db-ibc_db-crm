USE [bodb_CRM]
GO
/****** Object:  StoredProcedure [dbo].[ELMAH_GetErrorXml]    Script Date: 02/29/2012 22:45:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[ELMAH_GetErrorXml]
(
    @Application NVARCHAR(60),
    @ErrorId UNIQUEIDENTIFIER
)
AS
/*
	Created: Lukas
	Date: 20101217
	Task : get error xml by ID
	DB: DB06.bodb_CRM
	Original: ELMAH framework

	Revisions:
		
	Param's Explanation:	
*/
BEGIN
    SET NOCOUNT ON

    SELECT 
        [AllXml]
    FROM 
        [ELMAH_Error] WITH (NOLOCK)
    WHERE
        [ErrorId] = @ErrorId
    AND
        [Application] = @Application
END


GO
GRANT EXECUTE ON [dbo].[ELMAH_GetErrorXml] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[ELMAH_GetErrorXml] TO [vnteam]