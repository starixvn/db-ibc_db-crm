ALTER PROCEDURE [dbo].[ELMAH_LogError]
(
    @ErrorId		UNIQUEIDENTIFIER,
    @Application	NVARCHAR(60),
    @Host			NVARCHAR(30),
    @Type			NVARCHAR(100),
    @Source			NVARCHAR(60),
    @Message		NVARCHAR(500),
    @User			NVARCHAR(50),
    @AllXml			NTEXT,
    @StatusCode		INT,
    @TimeUtc		DATETIME
)
AS
/*
	Created: Lukas
	Date: 20101217
	Task : write to ELMAH_Eror
	DB: DB06.bodb_CRM
	Original: ELMAH framework

	Revisions:
		
	Param's Explanation:	
*/
BEGIN
    SET NOCOUNT ON

    INSERT
    INTO
        [ELMAH_Error]
        (
            [ErrorId],
            [Application],
            [Host],
            [Type],
            [Source],
            [Message],
            [User],
            [AllXml],
            [StatusCode],
            [TimeUtc]
        )
    VALUES
        (
            @ErrorId,
            @Application,
            @Host,
            @Type,
            @Source,
            @Message,
            @User,
            @AllXml,
            @StatusCode,
            @TimeUtc
        )
END
GO

GRANT EXECUTE ON [dbo].[ELMAH_LogError] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[ELMAH_LogError] TO [vnteam] 