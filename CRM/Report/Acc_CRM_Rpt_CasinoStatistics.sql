

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_CasinoStatistics]
(
	@Type		INT = 1,
	@fromdate	DATETIME,
	@todate		DATETIME
)
AS
/*
	Created: 20110826@Lukas	
	Task :  related casino feedback statistics report
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20111126@Sophia: Not to show Status is Pending	(StatusID = 11001)
		- 20120326@Sophia: remove IsActive = 1
		- 20120420@Sophia: Add ProductID = 8014 for Live Casino 
		- 20120425@Sophia: remove converting @FromDate, @Todate
		- 20120710@Sophia: Add ProductID = 8013 for Mini Game
		- 20120730@Sophia: Add ProductID = 8017 for Poker
	Param's Explanation:
		@Type:	- 1	Daily
				- 2	Weekly	
				- 3 Summary		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @category TABLE (MaincategoryID INT, Maincategory NVARCHAR(100))	

	DECLARE @tmp TABLE (
			MaincategoryID			INT,
			Maincategory			NVARCHAR(100),				
			IBCBetCasino_Call		INT,
			IBCBetCasino_Email		INT,
			IBCBetCasino_MSN		INT,
			IBCBetCasino_Skype		INT,
			IBCBetCasino_LiveChat	INT,

			NumberGame_Call			INT,
			NumberGame_Email		INT,
			NumberGame_MSN			INT,
			NumberGame_Skype		INT,
			NumberGame_LiveChat		INT,

			Bet2_Call				INT,
			Bet2_Email				INT,
			Bet2_MSN				INT,
			Bet2_Skype				INT,
			Bet2_LiveChat			INT,
			
			LiveCS_Call				INT,
			LiveCS_Email			INT,
			LiveCS_MSN				INT,
			LiveCS_Skype			INT,
			LiveCS_LiveChat			INT,
			
			MiniGame_Call			INT,
			MiniGame_Email			INT,
			MiniGame_MSN			INT,
			MiniGame_Skype			INT,
			MiniGame_LiveChat		INT,
			
			Poker_Call			INT,
			Poker_Email			INT,
			Poker_MSN			INT,
			Poker_Skype			INT,
			Poker_LiveChat		INT					
		)

	INSERT INTO @category(MaincategoryID,Maincategory)
		SELECT SettingID AS MaincategoryID, SettingValue AS Maincategory
		FROM crmSetting WITH(NOLOCK)
		WHERE SettingName = 'Maincategory'

	
	INSERT INTO @tmp
	SELECT	ISNULL(m.SettingID, 0) AS MainCategoryID,
			ISNULL(m.SettingValue,'N/A') AS MainCategory, 				
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1000 THEN 1 ELSE 0 END) IBCBetCasino_Call,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1001 THEN 1 ELSE 0 END) IBCBetCasino_Email,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1002 THEN 1 ELSE 0 END) IBCBetCasino_MSN,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1003 THEN 1 ELSE 0 END) IBCBetCasino_Skype,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1004 THEN 1 ELSE 0 END) IBCBetCasino_LiveChat,

			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1000 THEN 1 ELSE 0 END) NumberGame_Call,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1001 THEN 1 ELSE 0 END) NumberGame_Email,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1002 THEN 1 ELSE 0 END) NumberGame_MSN,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1003 THEN 1 ELSE 0 END) NumberGame_Skype,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1004 THEN 1 ELSE 0 END) NumberGame_LiveChat,

			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1000 THEN 1 ELSE 0 END) Bet2_Call,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1001 THEN 1 ELSE 0 END) Bet2_Email,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1002 THEN 1 ELSE 0 END) Bet2_MSN,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1003 THEN 1 ELSE 0 END) Bet2_Skype,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1004 THEN 1 ELSE 0 END) Bet2_LiveChat,
			
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1000 THEN 1 ELSE 0 END) LiveCS_Call,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1001 THEN 1 ELSE 0 END) LiveCS_Email,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1002 THEN 1 ELSE 0 END) LiveCS_MSN,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1003 THEN 1 ELSE 0 END) LiveCS_Skype,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1004 THEN 1 ELSE 0 END) LiveCS_LiveChat,
			
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1000 THEN 1 ELSE 0 END) MiniGame_Call,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1001 THEN 1 ELSE 0 END) MiniGame_Email,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1002 THEN 1 ELSE 0 END) MiniGame_MSN,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1003 THEN 1 ELSE 0 END) MiniGame_Skype,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1004 THEN 1 ELSE 0 END) MiniGame_LiveChat,
			
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1000 THEN 1 ELSE 0 END) Poker_Call,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1001 THEN 1 ELSE 0 END) Poker_Email,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1002 THEN 1 ELSE 0 END) Poker_MSN,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1003 THEN 1 ELSE 0 END) Poker_Skype,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1004 THEN 1 ELSE 0 END) Poker_LiveChat
	FROM crmFeedback fb WITH(NOLOCK) 
			LEFT JOIN crmSetting m WITH(NOLOCK) ON fb.MainCategoryID = m.SettingID
	WHERE ProductID IN (8003,8008,8011,8013,8014,8017) 
			AND fb.feedbackdate BETWEEN @fromdate AND @todate
			AND fb.StatusID NOT IN ( 11004, 11001)
	GROUP BY m.SettingID,m.SettingValue
	


	IF @Type = 3
	BEGIN
		SELECT	
			c.MainCategoryID,
			c.MainCategory, 						
			ISNULL(Bet2_Call + Bet2_Email + Bet2_MSN + Bet2_Skype + Bet2_LiveChat,0) AS Bet2,
			ISNULL(IBCBetCasino_Call + IBCBetCasino_Email + IBCBetCasino_MSN + IBCBetCasino_Skype + IBCBetCasino_LiveChat,0) AS IBCBetCasino,	
			ISNULL(NumberGame_Call + NumberGame_Email + NumberGame_MSN + NumberGame_Skype + NumberGame_LiveChat,0) AS NumberGame,
			ISNULL(LiveCS_Call + LiveCS_Email + LiveCS_MSN + LiveCS_Skype + LiveCS_LiveChat,0) AS LiveCS,
			ISNULL(MiniGame_Call + MiniGame_Email + MiniGame_MSN + MiniGame_Skype + MiniGame_LiveChat,0) AS MiniGame,
			ISNULL(Poker_Call + Poker_Email + Poker_MSN + Poker_Skype + Poker_LiveChat,0) AS PokerGame
		FROM @category c 
			LEFT JOIN @tmp t ON c.MaincategoryId = t.MaincategoryID
		ORDER BY MainCategoryID
	END
	ELSE
		SELECT	c.MaincategoryID, 
				c.Maincategory,
				ISNULL(t.IBCBetCasino_Call,0) IBCBetCasino_Call,
				ISNULL(t.IBCBetCasino_Email,0) IBCBetCasino_Email,
				ISNULL(t.IBCBetCasino_MSN,0) IBCBetCasino_MSN,
				ISNULL(t.IBCBetCasino_Skype,0) IBCBetCasino_Skype,
				ISNULL(t.IBCBetCasino_LiveChat,0) IBCBetCasino_LiveChat,

				ISNULL(t.NumberGame_Call,0) NumberGame_Call,
				ISNULL(t.NumberGame_Email,0) NumberGame_Email,
				ISNULL(t.NumberGame_MSN,0) NumberGame_MSN,
				ISNULL(t.NumberGame_Skype,0) NumberGame_Skype,
				ISNULL(t.NumberGame_LiveChat,0) NumberGame_LiveChat,

				ISNULL(t.Bet2_Call,0) Bet2_Call,
				ISNULL(t.Bet2_Email,0) Bet2_Email,
				ISNULL(t.Bet2_MSN,0) Bet2_MSN,
				ISNULL(t.Bet2_Skype,0) Bet2_Skype,
				ISNULL(t.Bet2_LiveChat,0) Bet2_LiveChat,
				
				ISNULL(t.LiveCS_Call,0) LiveCS_Call,
				ISNULL(t.LiveCS_Email,0) LiveCS_Email,
				ISNULL(t.LiveCS_MSN,0) LiveCS_MSN,
				ISNULL(t.LiveCS_Skype,0) LiveCS_Skype,
				ISNULL(t.LiveCS_LiveChat,0) LiveCS_LiveChat,
				
				ISNULL(t.MiniGame_Call,0) MiniGame_Call,
				ISNULL(t.MiniGame_Email,0) MiniGame_Email,
				ISNULL(t.MiniGame_MSN,0) MiniGame_MSN,
				ISNULL(t.MiniGame_Skype,0) MiniGame_Skype,
				ISNULL(t.MiniGame_LiveChat,0) MiniGame_LiveChat,
				
				ISNULL(t.Poker_Call,0) Poker_Call,
				ISNULL(t.Poker_Email,0) Poker_Email,
				ISNULL(t.Poker_MSN,0) Poker_MSN,
				ISNULL(t.Poker_Skype,0) Poker_Skype,
				ISNULL(t.Poker_LiveChat,0) Poker_LiveChat
		FROM @category c 
			LEFT JOIN @tmp t ON c.MaincategoryId = t.MaincategoryID
		ORDER BY MaincategoryID
END


GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CasinoStatistics] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CasinoStatistics] TO [vnteam]
