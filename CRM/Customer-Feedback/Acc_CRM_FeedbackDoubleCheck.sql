/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
USE [bodb_CRM]
GO

CREATE PROCEDURE [dbo].[Acc_CRM_FeedbackDoubleCheck]
	@Category		INT,
	@SubCategory	INT,
	@StartDate		DATETIME,	
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

	SELECT @FeedbackID=FeedbackID 
	FROM crmFeedback fb WITH(NOLOCK) 
	WHERE fb.FeedbackDate		=	@StartDate 
		AND fb.MainCategoryID	=	@Category 
		AND fb.SubCategoryID	=	@SubCategory	
END
GO