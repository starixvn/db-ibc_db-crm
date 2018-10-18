/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
USE [bodb_CRM]
GO

CREATE PROCEDURE [dbo].[Acc_CRM_FeedbackDoubleCheck]
	@Category		VARCHAR(MAX),	
	@StartTime		DATETIME,	
	@CustID			INT,
	@FeedbackID		INT	= 0	OUTPUT,
	@TimeSpan		INT
AS	
/*
	Created: Winnie
	Date: 2018-09-11
	Task: Check double Feedback
	DB: DBCRM/bodb_CRM		
	Revisions:	
		- 20180911@Winnie: Check double Feedback RedmineID #99982
		- 20181004@Winnie: Message warnings are still displayed although user create customer feedback for the other users RedmineID #102672
		- 20181009@Winnie: Include time in checking duplicated entry RedmineID #102923
	Parameter's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @tblCategory TABLE(MainCategoryID		INT,SubCategoryID		INT	)

		-- Read XML
	DECLARE	@iDoc			INT;
	EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @Category;

	INSERT INTO	@tblCategory
		( MainCategoryID,SubCategoryID)
	SELECT	ox.MainCategoryID, ox.SubCategoryID
	FROM	OPENXML(@iDoc, '/ROOT/Category', 1)
			WITH (		
				MainCategoryID				INT
			,	SubCategoryID				INT					
			) AS ox;

	EXECUTE sys.sp_xml_removedocument @iDoc;	

	SELECT @FeedbackID=fb.FeedbackID 
	FROM crmFeedback fb WITH(NOLOCK) 
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) ON fb.FeedbackID=fs.FeedbackID
		INNER JOIN @tblCategory t ON fs.SettingID=t.MainCategoryID AND fs.SubSettingID=t.SubCategoryID
	WHERE CONVERT(SMALLDATETIME,DATEADD(HOUR, @TimeSpan,  fb.FeedbackDate))		=	CONVERT(SMALLDATETIME,@StartTime)
		AND fb.CustID=@CustID
		
END
GO
