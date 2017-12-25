 /*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="1"></info>*/
ALTER  FUNCTION [dbo].[f_GetFeedbackSetting]   
( 
	@FeedbackID		INT, 
	@SettingID		INT,
	@SubSettingID	INT,
	@Mode			INT	= 1
)  
RETURNS @tbFeedbackSetting TABLE (FeedbackID INT,SettingID INT, SubSettingID INT,SubSettingIDLevel3 INT)
AS
/*
Created: 
Task : Get feedback setting
DB: DBCRM.bodb_CRM

Revisions:
	- 20171222@Winnie: Get feedback Setting [RedmineID: #84714]
	Param's Explanation:
	- @Mode: 
		1: Setting level 1
		2: Setting level 2
		3: Setting level 3
*/
BEGIN
	IF(@Mode=1)
		BEGIN
			INSERT INTO @tbFeedbackSetting(FeedbackID,SettingID)
			SELECT DISTINCT FeedbackID,SettingID
			FROM dbo.crmFeedbackSetting WITH(NOLOCK)
			WHERE (@feedbackID=0 OR @feedbackID=FeedbackID) AND (@SettingID=0 OR (SettingID=@SettingID)) AND(@SubSettingID=0 OR (SubSettingID=@SubSettingID))    		
			
		END
	ELSE IF(@Mode=2)
		BEGIN
			INSERT INTO @tbFeedbackSetting(FeedbackID,SettingID,SubSettingID)
			SELECT DISTINCT FeedbackID,SettingID,SubSettingID
			FROM dbo.crmFeedbackSetting WITH(NOLOCK)
			WHERE (@feedbackID=0 OR @feedbackID=FeedbackID) AND (@SettingID=0 OR (SettingID=@SettingID)) AND(@SubSettingID=0 OR (SubSettingID=@SubSettingID))    		
			
		END
	ELSE IF(@Mode=3)
		BEGIN
			INSERT INTO @tbFeedbackSetting(FeedbackID,SettingID,SubSettingID,SubSettingIDLevel3)
			SELECT DISTINCT FeedbackID,SettingID,SubSettingID,SubSettingIDLevel3
			FROM dbo.crmFeedbackSetting WITH(NOLOCK)
			WHERE (@feedbackID=0 OR @feedbackID=FeedbackID) AND (@SettingID=0 OR (SettingID=@SettingID)) AND(@SubSettingID=0 OR (SubSettingID=@SubSettingID))    		
			
		END
	RETURN
END
GO