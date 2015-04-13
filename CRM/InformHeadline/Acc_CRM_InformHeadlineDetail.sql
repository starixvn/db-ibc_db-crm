ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineDetail]
	@TitleID			INT,
	@UserName			NVARCHAR(50) = '',
	@StatusID			VARCHAR(100) = '',	
	@PageIndex			INT = 1, 
	@ItemsPerPage		INT = 100
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Inform headline detail
	DB: DBCRM/bodb_CRM
		
	Revisions:

	Parameter's Explanation:				
		
	Example: EXEC Acc_CRM_InformHeadlineDetail @TitleID = 1, @UserName = 'Supert', @StatusID = '45001,45002,45006'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpStatus TABLE (StatusID INT)	

	INSERT INTO @tmpStatus
	SELECT val
	FROM f_split (@StatusID,',')

	IF @ItemsPerPage = -1 -- Export excel purpose
	BEGIN
		SELECT ID, HeadlineID, username, InformHeadlineStatusID, UpdatedTime, Remark, Handler, Extension, ProductStatus
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY ih.GroupID DESC, c.username) AS ID,
						ih.HeadlineID, 
						c.username, 
						ih.InformHeadlineStatusID, 
						ih.UpdatedTime, 
						ih.Remark, 
						ISNULL(handler.username, '') AS Handler,
						st.SettingValue AS Extension,
						ih.ProductStatus
				FROM crmInformHeadline ih WITH (NOLOCK)
					INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON ih.HeadlineID = c.custid
					LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid				
					LEFT JOIN crmSetting st WITH(NOLOCK) ON ih.Extension = st.SettingID AND st.SettingName = 'Station'		 			
				WHERE TitleID = @TitleID 
					AND c.username LIKE '%' + @UserName + '%'
					AND ih.InformHeadlineStatusID IN (SELECT StatusID FROM @tmpStatus) AND ih.IsInform = 1
				) tmp
	END
	ELSE
	BEGIN
		SELECT ID, HeadlineID, username, InformHeadlineStatusID, UpdatedTime, Remark, Handler, Extension, ProductStatus
		FROM (
				SELECT	ROW_NUMBER() OVER ( ORDER BY ih.GroupID DESC, c.username) AS ID,
						ih.HeadlineID, 
						c.username, 
						ih.InformHeadlineStatusID, 
						ih.UpdatedTime, 
						ih.Remark, 
						ISNULL(handler.username, '') AS Handler,
						st.SettingValue AS Extension,
						ih.ProductStatus
				FROM crmInformHeadline ih WITH (NOLOCK)
					INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON ih.HeadlineID = c.custid
					LEFT JOIN bodb02.dbo.CustInfo handler WITH (NOLOCK) ON ih.Handler = handler.custid				
					LEFT JOIN crmSetting st WITH(NOLOCK) ON ih.Extension = st.SettingID AND st.SettingName = 'Station'		 			
				WHERE TitleID = @TitleID
					AND c.username LIKE '%' + @UserName + '%'
					AND ih.InformHeadlineStatusID IN (SELECT StatusID FROM @tmpStatus) AND ih.IsInform = 1				
				) tmp
		WHERE ID BETWEEN @PageIndex*@ItemsPerPage-@ItemsPerPage+1 AND @PageIndex*@ItemsPerPage		
	END		
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineDetail] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineDetail] TO [vnteam]