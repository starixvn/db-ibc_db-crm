USE [bodb_CRM]
GO
/****** Object:  StoredProcedure [dbo].[Acc_CRM_GuestFeedbackUpd_Site_LicenseeType]    Script Date: 6/8/2017 1:00:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Acc_CRM_GuestFeedbackIns_Multiple    Script Date: 2/21/2017 2:17:13 PM ******/
/****** Object:  Stored Procedure dbo.Acc_CRM_GuestFeedbackIns    Script Date: 4/26/2016 8:58:07 AM ******/


ALTER PROCEDURE	[dbo].[Acc_CRM_GuestFeedbackUpd_Site_LicenseeType] (
					@UserID						INT
				,	@ListFeedbackID				VARCHAR(MAX)
				,	@ErrCode					INT				= 0 OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT
				,	@IP							VARCHAR(15)
				)
AS
/*
	Created:	Winnie
	Date:		20170607
	Task :		update site/LicenseeType for multiple log [RedmineID:#77820]
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
	
	Param's Explanation:
		
*/
BEGIN	
	SET NOCOUNT ON;

				

DECLARE @Old_SiteID INT,@Old_LicenseeType INT,@New_SiteID INT,@New_LicenseeType INT

DECLARE @tmpFeedbackID TABLE (FeedbackID INT)

INSERT INTO @tmpFeedbackID(FeedbackID)
	SELECT val
	FROM f_CRM_strSplit (@ListFeedbackID,',')		

IF	EXISTS (SELECT TOP 1 1 FROM @tmpFeedbackID t LEFT JOIN crmFeedback c WITH(NOLOCK) ON t.FeedbackID=c.FeedbackID WHERE c.FeedbackID IS NULL)
BEGIN
	SELECT	@ErrCode = 100
		,	@ErrMsg = 'Feedback does not exist.';

	RETURN;
END;

WHILE EXISTS(SELECT TOP 1 FeedbackID FROM @tmpFeedbackID)
BEGIN
	DECLARE @FeedbackID INT,@CustID INT	
	SELECT	@ErrCode = 0
		,	@ErrMsg	 = '';

	SELECT TOP 1 @Custid=Custid,@Old_SiteID=SiteID,@Old_LicenseeType=LicenseeType,@FeedbackID=cb.FeedbackID
	FROM  [dbo].[crmFeedback] cb WITH(NOLOCK) 
	INNER JOIN @tmpFeedbackID t ON cb.FeedbackID=t.FeedbackID	
	
	SELECT @New_SiteID=SiteID,@New_LicenseeType=LicenseeType
	FROM crmCustomer c WITH(NOLOCK) WHERE CustID=@CustID 

	UPDATE cb SET cb.SiteID=@New_SiteID,cb.LicenseeType=@New_LicenseeType
	FROM [dbo].[crmFeedback] cb WITH(ROWLOCK,UPDLOCK) WHERE Feedbackid=@FeedbackID
	  
	IF	@ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = 102;
		SELECT	@ErrMsg  = 'Update failed'
		RETURN;
	END;

	-- write log
	DECLARE	@OldValues	XML
		,	@NewValues	XML;
	SELECT	@OldValues = 				
					'<Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>' + --SP Name
						'<FeedbackID>'						+ ISNULL(CONVERT(VARCHAR(5),@FeedbackID),'')				+ '</FeedbackID>' +
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(5),@Old_SiteID),'')					+ '</SiteID>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(5),@Old_LicenseeType),'')				+ '</LicenseeType>' +
						
					'</Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>';
	SELECT @NewValues = 				
					'<Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>' + --SP Name
						'<FeedbackID>'						+ ISNULL(CONVERT(VARCHAR(5),@FeedbackID),'')				+ '</FeedbackID>' +
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(5),@New_SiteID),'')					+ '</SiteID>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(5),@New_LicenseeType),'')				+ '</LicenseeType>' +
					'</Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>';

	EXECUTE	dbo.WriteLog_UserLog_crmLogFeedback
			@UserID = @UserID
		,	@FeedbackID = @FeedbackID
		,	@CustID = @CustID
		,	@ActionID = 704
		,	@IP = @IP
		,	@Description = ''
		,	@Solution = ''
		,	@Review =  ''
		,	@NewValues = @NewValues
		,	@OldValues = @OldValues;


	DELETE FROM @tmpFeedbackID WHERE FeedbackID=@FeedbackID
END

	
END



GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_GuestFeedbackUpd_Site_LicenseeType] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_GuestFeedbackUpd_Site_LicenseeType] TO [vnteam]
GO 
