/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PICAssignment]
	@HeadlineID		INT,
	@PicID			VARCHAR(200),
	@DirectAccount	VARCHAR(1000),
	@IsKeepAssign   BIT = 1,
	@UserID			INT,
	@LoginIP        VARCHAR(20) ='',
	@ErrorCode      INT = 0 OUTPUT,
	@ErrorMsg       NVARCHAR(MAX) = '' OUTPUT
	
AS
/*
Created: 20200506@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: CRM - Staff/Boss Management of headline [Redmine: #108739]
	Param's Explanation:
	
		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #DirectAccountTmp (CustID INT, Username VARCHAR(30))

	CREATE TABLE #LogForNewAssignPIC(HeadlineName VARCHAR(30), PicName NVARCHAR(200), PicID INT, Username VARCHAR(30), CustID INT)

	CREATE TABLE #LogForRemovePIC(HeadlineName VARCHAR(30), PicName NVARCHAR(200), PicID INT, Username VARCHAR(30), CustID INT)

	DECLARE @HeadlineName VARCHAR(30) = '', @GroupID INT = 0,@NewValues XML, @OldValues XML
	
	SELECT @HeadlineID = ISNULL(@HeadlineID,0)

	SELECT @HeadlineName = Username FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid = @HeadlineID

	SELECT @GroupID = GroupID FROM bodb02.dbo.CustGroupHeadline WITH(NOLOCK) WHERE custid = @HeadlineID

	INSERT INTO #DirectAccountTmp
	(
		CustID,
		Username
	)
	SELECT DISTINCT Custid,Username
	FROM bodb02.dbo.Customer WITH(NOLOCK)
	WHERE ',' + @DirectAccount + ',' LIKE '%,' + username + ',%'

	SET @IsKeepAssign = ISNULL(@IsKeepAssign,0)

	BEGIN TRY
		IF @IsKeepAssign = 0 
		BEGIN
		
			DELETE m
			OUTPUT @HeadlineName, p.Username, p.PicID,t.Username, t.CustID
			INTO #LogForRemovePIC
			FROM dbo.crmPicManagement m
				INNER JOIN #DirectAccountTmp t ON m.CustID = t.CustID
				LEFT JOIN  dbo.crmPIC p WITH(NOLOCK) ON p.PicID = m.PicID

			DELETE h
			FROM dbo.crmPICHeadline h
			WHERE h.HeadlineID = @HeadlineID  
				AND h.PicID IN (SELECT PicID FROM #LogForRemovePIC)

			INSERT INTO dbo.crmPICHeadline
			(
				HeadlineID,
				PicID
			)
			SELECT DISTINCT @HeadlineID, m.PicID
			FROM dbo.crmPicManagement m WITH(NOLOCK)
				INNER JOIN bodb02.dbo.CustAccount c WITH(NOLOCK) ON m.CustID = c.custid
			WHERE  c.groupID = @GroupID  AND @GroupID <> 0
				AND m.PicID IN (SELECT PicID FROM #LogForRemovePIC)			
		END

		INSERT INTO #LogForNewAssignPIC
		(
				HeadlineName,
				PicName,
				PicID,
				Username,
				CustID
		)		
		SELECT	@HeadlineName,
				l.PicName,
				l.PicID, 
				t.Username,		
				t.CustID
		FROM #DirectAccountTmp t
		   CROSS APPLY(
			SELECT Val AS PicID , r.Username AS PicName
			FROM bodb02.dbo.strSplit(@PicID,',') AS s
				INNER JOIN dbo.crmPIC r WITH(NOLOCK) ON s.val = r.PicID
		)l

		INSERT INTO dbo.crmPicManagement
		(
				PicID,
				CustID
		)		
		SELECT	PicID,
				CustID
		FROM #LogForNewAssignPIC l
		WHERE @IsKeepAssign = 0 
		OR NOT EXISTS(SELECT 1 
			FROM dbo.crmPicManagement WITH(NOLOCK) 
			WHERE PicID = l.PicID AND CustID = l.CustID)

		INSERT INTO dbo.crmPICHeadline
		(
			HeadlineID,
			PicID
		)
		SELECT DISTINCT @HeadlineID,l.PicID
		FROM #LogForNewAssignPIC l
		WHERE NOT EXISTS(
			SELECT 1 
			FROM dbo.crmPICHeadline h WITH(NOLOCK) 
			WHERE h.HeadlineID = @HeadlineID AND h.PicID = l.PicID
		) AND @HeadlineID <> 0

	END TRY
	BEGIN CATCH
		SELECT @ErrorCode = ERROR_NUMBER(), @ErrorMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
	
	IF @IsKeepAssign = 0
	BEGIN
		SELECT @NewValues =	(SELECT @HeadlineID		AS 'GroupHeadline/@HeadlineID',
									HeadlineName	AS 'GroupHeadline/@HeadlineName',
									PicID			AS 'Pic/@PicID',
									PicName			AS 'Pic/@PicName', 
									CustID			AS 'DirectAccount/@CustID',
									Username		AS 'DirectAccount/@Username'
							 FROM #LogForRemovePIC
							 FOR XML PATH('AssignedPIC'),ROOT('Acc_CRM_PICAssignment'))

		EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
				@UserID = @UserID,
				@ActionID = 904,
				@IP = @LoginIP,
				@NewValues = @NewValues
	END 

	SELECT @NewValues =	(SELECT @HeadlineID		AS 'GroupHeadline/@HeadlineID',
								HeadlineName	AS 'GroupHeadline/@HeadlineName',
								PicID			AS 'Pic/@PicID',
								PicName			AS 'Pic/@PicName', 
								CustID			AS 'DirectAccount/@CustID',
								Username		AS 'DirectAccount/@Username'
						 FROM #LogForNewAssignPIC
						 FOR XML PATH('AssignedPIC'),ROOT('Acc_CRM_PICAssignment'))
	
	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@ActionID = 905,
			@IP = @LoginIP,
			@NewValues = @NewValues  
    
	DROP TABLE #DirectAccountTmp
	DROP TABLE #LogForNewAssignPIC
	DROP TABLE #LogForRemovePIC
END