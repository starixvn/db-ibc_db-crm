/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_Chatbot_TOControlSetting_Sel]
	@LastLogId BIGINT
	,@BatchSize INT = 10
AS

/*
	Created: 20201214@Malcolm
	DB: DBCUST-CustDB
	Task: Get logIds which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #146735]

	Param's Explanation:
		

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @NumberOfRows INT, @MinLogId BIGINT

	DECLARE @Result TABLE (LogId BIGINT, CustId INT, MatchId INT, NotifiedPercentValue MONEY, IsGroupHeadLine BIT)

	DECLARE @Inserted TABLE (LogId BIGINT)

	WHILE 1 = 1
	BEGIN
		INSERT INTO @Result (LogId, CustId, MatchId, NotifiedPercentValue, IsGroupHeadLine)
		OUTPUT inserted.LogId
			INTO @Inserted
		SELECT TOP(@BatchSize) LogID, h.CustID, Matchid, NotifiedPercentValue, IsGroupHeadLine
		FROM dbo.TOControl_Setting_History h WITH(NOLOCK)
		WHERE h.LogID > @LastLogId 
		ORDER BY h.LogID	

		IF @@ROWCOUNT = 0
			BREAK

		SET @MinLogId = @LastLogId 

		SELECT @LastLogId = MAX(LogId) FROM @Result

		/*check what if data have missed or not
		  Error description: 
		  Data on TOControl_Setting_History in present  
			+ row1 : LogId = 1
			+ row2 : LogId = 2
			+ row3 : LogId = 4
		=> get data form TOControl_Setting_History => miss LogId = 3 => return 0 rows
		*/
		BEGIN
			;WITH CTE (LogID) AS 
			( 
				SELECT @MinLogId + 1
				UNION ALL
				SELECT LogID + 1
				FROM CTE
				WHERE LogID < CASE WHEN (@MinLogId + @BatchSize) > @LastLogId THEN @LastLogId ELSE (@MinLogId + @BatchSize) END
			)
			INSERT INTO @Inserted (LogId)
			SELECT LogID
			FROM CTE
			OPTION (MAXRECURSION 0)

			IF EXISTS(SELECT TOP 1 1 FROM @Inserted GROUP BY LogId HAVING COUNT(1) <> 2)
			BEGIN
				 SELECT NULL  LogId ,NULL CustId ,NULL MatchId 
				 WHERE 1 = 2
				 RETURN
			END

			DELETE @Inserted
		END	

		DELETE @Result WHERE NotifiedPercentValue < 80 OR IsGroupHeadLine = 1

		DELETE r
		FROM @Result r
		WHERE EXISTS(SELECT TOP 1 1 FROM dbo.Customer c WITH(NOLOCK) WHERE c.custid = r.CustId AND c.site = 'CN88') 

		SELECT @NumberOfRows = COUNT(1) FROM @Result

		IF @NumberOfRows >= @BatchSize
			BREAK
	END
	
	SELECT TOP(@BatchSize) LogId ,CustId ,MatchId FROM @Result
	ORDER BY LogId

END
GO