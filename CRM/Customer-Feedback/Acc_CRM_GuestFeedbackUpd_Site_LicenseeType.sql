/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
USE [bodb_CRM]
GO

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
	- 20170607@Winnie: Create new		[RedmineID: #77820]
	- 20180910@Winnie: Update RoleID	[RedmineID: #99982]
	Param's Explanation:
		
*/
BEGIN	
	SET NOCOUNT ON;

				

DECLARE @Old_SiteID			INT,
		@Old_LicenseeType	INT,
		@Old_RoleID			INT,
		@New_SiteID			INT,
		@New_LicenseeType	INT,
		@New_RoleID			INT

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

	SELECT TOP 1 @Custid			=	Custid,
				@Old_SiteID			=	SiteID,
				@Old_LicenseeType	=	LicenseeType,
				@FeedbackID			=	cb.FeedbackID,
				@Old_RoleID			=	cb.RoleID
	FROM  [dbo].[crmFeedback] cb WITH(NOLOCK) 
	INNER JOIN @tmpFeedbackID t ON cb.FeedbackID=t.FeedbackID	
	
	SELECT	@New_SiteID			=	SiteID,
			@New_LicenseeType	=	LicenseeType
	FROM crmCustomer c WITH(NOLOCK) 
	WHERE CustID=@CustID 

	SELECT @New_RoleID	=	roleid
	FROM DBACC.bodb02.dbo.Customer c WITH(NOLOCK) 
	WHERE CustID=@CustID 

	UPDATE cb 
		SET cb.SiteID		=	@New_SiteID,
			cb.LicenseeType	=	@New_LicenseeType
	FROM [dbo].[crmFeedback] cb WITH(ROWLOCK,UPDLOCK) 
		WHERE Feedbackid=@FeedbackID

	IF(@New_RoleID IS NOT NULL)
		UPDATE cb 
			SET cb.RoleID		=	@New_RoleID
		FROM [dbo].[crmFeedback] cb WITH(ROWLOCK,UPDLOCK) 
			WHERE Feedbackid=@FeedbackID
	  
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
					'<Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>'	+ --SP Name
						'<FeedbackID>'								+ ISNULL(CONVERT(VARCHAR(30),@FeedbackID),'')					+ '</FeedbackID>' +
						'<SiteID>'									+ ISNULL(CONVERT(VARCHAR(5),@Old_SiteID),'')					+ '</SiteID>' +
						'<LicenseeType>'							+ ISNULL(CONVERT(VARCHAR(5),@Old_LicenseeType),'')				+ '</LicenseeType>' +
						'<RoleID>'									+ ISNULL(CONVERT(VARCHAR(5),@Old_RoleID),'')					+ '</RoleID>' +
					'</Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>';
	IF(@New_RoleID IS NOT NULL)
		SELECT @NewValues = 				
						'<Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>'	+ --SP Name
							'<FeedbackID>'								+ ISNULL(CONVERT(VARCHAR(30),@FeedbackID),'')					+ '</FeedbackID>' +
							'<SiteID>'									+ ISNULL(CONVERT(VARCHAR(5),@New_SiteID),'')					+ '</SiteID>' +
							'<LicenseeType>'							+ ISNULL(CONVERT(VARCHAR(5),@New_LicenseeType),'')				+ '</LicenseeType>' +
							'<RoleID>'									+ ISNULL(CONVERT(VARCHAR(5),@New_RoleID),'')					+ '</RoleID>' +
						'</Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>';
	ELSE 
		SELECT @NewValues = 				
						'<Acc_CRM_GuestFeedbackUpd_Site_LicenseeType>'	+ --SP Name
							'<FeedbackID>'								+ ISNULL(CONVERT(VARCHAR(30),@FeedbackID),'')					+ '</FeedbackID>' +
							'<SiteID>'									+ ISNULL(CONVERT(VARCHAR(5),@New_SiteID),'')					+ '</SiteID>' +
							'<LicenseeType>'							+ ISNULL(CONVERT(VARCHAR(5),@New_LicenseeType),'')				+ '</LicenseeType>' +
							'<RoleID>'									+ ISNULL(CONVERT(VARCHAR(5),@Old_RoleID),'')					+ '</RoleID>' +
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
