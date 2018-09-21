/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
USE [bodb_CRM]
GO

CREATE PROCEDURE [dbo].[Acc_CRM_FeedbackDoubleCheck]
	@Category		VARCHAR(MAX),	
	@StartTime		DATETIME,	
	@FeedbackID		INT	= 0	OUTPUT
AS	
/*
	Created: Winnie
	Date: 2018-09-11
	Task: Check double Feedback
	DB: DBCRM/bodb_CRM		
	Revisions:	
		- 20180911@Winnie: Check double Feedback RedmineID #99982
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
	WHERE fb.FeedbackDate		=	@StartTime 
		
END
GO