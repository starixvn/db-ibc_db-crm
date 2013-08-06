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
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20111126@Sophia: Not to show Status is Pending	(StatusID = 11001)
		- 20120326@Sophia: remove IsActive = 1
		- 20120420@Sophia: Add ProductID = 8014 for Live Casino 
		- 20120425@Sophia: remove converting @FromDate, @Todate
		- 20120710@Sophia: Add ProductID = 8013 for Mini Game
		- 20120730@Sophia: Add ProductID = 8017 for Poker
		- 20130607@Elodie: Add CommunicationID (1005->1010) for every ProductID
		- 20130805@Kathy:  Add ProductID = 8005 for Bingo
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
			IBCBetCasino_NA			INT,
			IBCBetCasino_Yahoo		INT,
			IBCBetCasino_WeChat		INT,
			IBCBetCasino_Line		INT,
			IBCBetCasino_WhatsApp	INT,
			IBCBetCasino_QQ			INT,			

			Bingo_Call				INT,
			Bingo_Email				INT,
			Bingo_MSN				INT,
			Bingo_Skype				INT,
			Bingo_LiveChat			INT,
			Bingo_NA				INT,
			Bingo_Yahoo				INT,
			Bingo_WeChat			INT,
			Bingo_Line				INT,
			Bingo_WhatsApp			INT,
			Bingo_QQ				INT,
			
			NumberGame_Call			INT,
			NumberGame_Email		INT,
			NumberGame_MSN			INT,
			NumberGame_Skype		INT,
			NumberGame_LiveChat		INT,
			NumberGame_NA			INT,
			NumberGame_Yahoo		INT,
			NumberGame_WeChat		INT,
			NumberGame_Line			INT,
			NumberGame_WhatsApp		INT,
			NumberGame_QQ			INT,			

			Bet2_Call				INT,
			Bet2_Email				INT,
			Bet2_MSN				INT,
			Bet2_Skype				INT,
			Bet2_LiveChat			INT,
			Bet2_NA					INT,
			Bet2_Yahoo				INT,
			Bet2_WeChat				INT,
			Bet2_Line				INT,
			Bet2_WhatsApp			INT,
			Bet2_QQ					INT,			
			
			LiveCS_Call				INT,
			LiveCS_Email			INT,
			LiveCS_MSN				INT,
			LiveCS_Skype			INT,
			LiveCS_LiveChat			INT,
			LiveCS_NA				INT,
			LiveCS_Yahoo			INT,
			LiveCS_WeChat			INT,
			LiveCS_Line				INT,
			LiveCS_WhatsApp			INT,
			LiveCS_QQ				INT,
			
			
			MiniGame_Call			INT,
			MiniGame_Email			INT,
			MiniGame_MSN			INT,
			MiniGame_Skype			INT,
			MiniGame_LiveChat		INT,
			MiniGame_NA				INT,
			MiniGame_Yahoo			INT,
			MiniGame_WeChat			INT,
			MiniGame_Line			INT,
			MiniGame_WhatsApp		INT,
			MiniGame_QQ				INT,
			
			
			Poker_Call			INT,
			Poker_Email			INT,
			Poker_MSN			INT,
			Poker_Skype			INT,
			Poker_LiveChat		INT,	
			Poker_NA			INT,
			Poker_Yahoo			INT,
			Poker_WeChat		INT,
			Poker_Line			INT,
			Poker_WhatsApp		INT,
			Poker_QQ			INT
						
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
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1005 THEN 1 ELSE 0 END) IBCBetCasino_NA,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1006 THEN 1 ELSE 0 END) IBCBetCasino_Yahoo,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1007 THEN 1 ELSE 0 END) IBCBetCasino_WeChat,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1008 THEN 1 ELSE 0 END) IBCBetCasino_Line,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1009 THEN 1 ELSE 0 END) IBCBetCasino_WhatsApp,
			SUM(CASE WHEN ProductID = 8003 AND CommunicationID = 1010 THEN 1 ELSE 0 END) IBCBetCasino_QQ,
			
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1000 THEN 1 ELSE 0 END) Bingo_Call,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1001 THEN 1 ELSE 0 END) Bingo_Email,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1002 THEN 1 ELSE 0 END) Bingo_MSN,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1003 THEN 1 ELSE 0 END) Bingo_Skype,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1004 THEN 1 ELSE 0 END) Bingo_LiveChat,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1005 THEN 1 ELSE 0 END) Bingo_NA,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1006 THEN 1 ELSE 0 END) Bingo_Yahoo,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1007 THEN 1 ELSE 0 END) Bingo_WeChat,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1008 THEN 1 ELSE 0 END) Bingo_Line,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1009 THEN 1 ELSE 0 END) Bingo_WhatsApp,
			SUM(CASE WHEN ProductID = 8005 AND CommunicationID = 1010 THEN 1 ELSE 0 END) Bingo_QQ,

			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1000 THEN 1 ELSE 0 END) NumberGame_Call,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1001 THEN 1 ELSE 0 END) NumberGame_Email,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1002 THEN 1 ELSE 0 END) NumberGame_MSN,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1003 THEN 1 ELSE 0 END) NumberGame_Skype,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1004 THEN 1 ELSE 0 END) NumberGame_LiveChat,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1005 THEN 1 ELSE 0 END) NumberGame_NA,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1006 THEN 1 ELSE 0 END) NumberGame_Yahoo,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1007 THEN 1 ELSE 0 END) NumberGame_WeChat,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1008 THEN 1 ELSE 0 END) NumberGame_Line,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1009 THEN 1 ELSE 0 END) NumberGame_WhatsApp,
			SUM(CASE WHEN ProductID = 8008 AND CommunicationID = 1010 THEN 1 ELSE 0 END) NumberGame_QQ,

			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1000 THEN 1 ELSE 0 END) Bet2_Call,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1001 THEN 1 ELSE 0 END) Bet2_Email,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1002 THEN 1 ELSE 0 END) Bet2_MSN,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1003 THEN 1 ELSE 0 END) Bet2_Skype,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1004 THEN 1 ELSE 0 END) Bet2_LiveChat,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1005 THEN 1 ELSE 0 END) Bet2_NA,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1006 THEN 1 ELSE 0 END) Bet2_Yahoo,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1007 THEN 1 ELSE 0 END) Bet2_WeChat,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1008 THEN 1 ELSE 0 END) Bet2_Line,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1009 THEN 1 ELSE 0 END) Bet2_WhatsApp,
			SUM(CASE WHEN ProductID = 8011 AND CommunicationID = 1010 THEN 1 ELSE 0 END) Bet2_QQ,
			
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1000 THEN 1 ELSE 0 END) LiveCS_Call,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1001 THEN 1 ELSE 0 END) LiveCS_Email,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1002 THEN 1 ELSE 0 END) LiveCS_MSN,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1003 THEN 1 ELSE 0 END) LiveCS_Skype,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1004 THEN 1 ELSE 0 END) LiveCS_LiveChat,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1005 THEN 1 ELSE 0 END) LiveCS_NA,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1006 THEN 1 ELSE 0 END) LiveCS_Yahoo,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1007 THEN 1 ELSE 0 END) LiveCS_WeChat,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1008 THEN 1 ELSE 0 END) LiveCS_Line,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1009 THEN 1 ELSE 0 END) LiveCS_WhatsApp,
			SUM(CASE WHEN ProductID = 8014 AND CommunicationID = 1010 THEN 1 ELSE 0 END) LiveCS_QQ,
			
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1000 THEN 1 ELSE 0 END) MiniGame_Call,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1001 THEN 1 ELSE 0 END) MiniGame_Email,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1002 THEN 1 ELSE 0 END) MiniGame_MSN,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1003 THEN 1 ELSE 0 END) MiniGame_Skype,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1004 THEN 1 ELSE 0 END) MiniGame_LiveChat,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1005 THEN 1 ELSE 0 END) MiniGame_NA,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1006 THEN 1 ELSE 0 END) MiniGame_Yahoo,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1007 THEN 1 ELSE 0 END) MiniGame_WeChat,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1008 THEN 1 ELSE 0 END) MiniGame_Line,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1009 THEN 1 ELSE 0 END) MiniGame_WhatsApp,
			SUM(CASE WHEN ProductID = 8013 AND CommunicationID = 1010 THEN 1 ELSE 0 END) MiniGame_QQ,
			
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1000 THEN 1 ELSE 0 END) Poker_Call,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1001 THEN 1 ELSE 0 END) Poker_Email,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1002 THEN 1 ELSE 0 END) Poker_MSN,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1003 THEN 1 ELSE 0 END) Poker_Skype,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1004 THEN 1 ELSE 0 END) Poker_LiveChat,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1005 THEN 1 ELSE 0 END) Poker_NA,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1006 THEN 1 ELSE 0 END) Poker_Yahoo,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1007 THEN 1 ELSE 0 END) Poker_WeChat,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1008 THEN 1 ELSE 0 END) Poker_Line,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1009 THEN 1 ELSE 0 END) Poker_WhatsApp,
			SUM(CASE WHEN ProductID = 8017 AND CommunicationID = 1010 THEN 1 ELSE 0 END) Poker_QQ
	FROM crmFeedback fb WITH(NOLOCK) 
			LEFT JOIN crmSetting m WITH(NOLOCK) ON fb.MainCategoryID = m.SettingID
	WHERE ProductID IN (8003, 8005, 8008,8011,8013,8014,8017) 
			AND fb.feedbackdate BETWEEN @fromdate AND @todate
			AND fb.StatusID NOT IN ( 11004, 11001)
	GROUP BY m.SettingID,m.SettingValue
	


	IF @Type = 3
	BEGIN
		SELECT	
			c.MainCategoryID,
			c.MainCategory, 						
			ISNULL(Bet2_Call + Bet2_Email + Bet2_MSN + Bet2_Skype + Bet2_LiveChat + Bet2_NA + Bet2_Yahoo + Bet2_WeChat + Bet2_Line + Bet2_WhatsApp + Bet2_QQ,0) AS Bet2,
			ISNULL(IBCBetCasino_Call + IBCBetCasino_Email + IBCBetCasino_MSN + IBCBetCasino_Skype + IBCBetCasino_LiveChat + IBCBetCasino_NA + IBCBetCasino_Yahoo + IBCBetCasino_WeChat + IBCBetCasino_Line + IBCBetCasino_WhatsApp + IBCBetCasino_QQ,0) AS IBCBetCasino,	
			ISNULL(NumberGame_Call + NumberGame_Email + NumberGame_MSN + NumberGame_Skype + NumberGame_LiveChat + NumberGame_NA + NumberGame_Yahoo + NumberGame_WeChat + NumberGame_Line + NumberGame_WhatsApp + NumberGame_QQ,0) AS NumberGame,
			ISNULL(LiveCS_Call + LiveCS_Email + LiveCS_MSN + LiveCS_Skype + LiveCS_LiveChat + LiveCS_NA + LiveCS_Yahoo + LiveCS_WeChat + LiveCS_Line + LiveCS_WhatsApp + LiveCS_QQ,0) AS LiveCS,
			ISNULL(MiniGame_Call + MiniGame_Email + MiniGame_MSN + MiniGame_Skype + MiniGame_LiveChat + MiniGame_NA + MiniGame_Yahoo + MiniGame_WeChat + MiniGame_Line + MiniGame_WhatsApp + MiniGame_QQ,0) AS MiniGame,
			ISNULL(Poker_Call + Poker_Email + Poker_MSN + Poker_Skype + Poker_LiveChat + Poker_NA + Poker_Yahoo + Poker_WeChat + Poker_Line + Poker_WhatsApp + Poker_QQ,0) AS PokerGame
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
				ISNULL(t.IBCBetCasino_NA,0) IBCBetCasino_NA,
				ISNULL(t.IBCBetCasino_Yahoo,0) IBCBetCasino_Yahoo,
				ISNULL(t.IBCBetCasino_WeChat,0) IBCBetCasino_WeChat,
				ISNULL(t.IBCBetCasino_Line,0) IBCBetCasino_Line,
				ISNULL(t.IBCBetCasino_WhatsApp,0) IBCBetCasino_WhatsApp,
				ISNULL(t.IBCBetCasino_QQ,0) IBCBetCasino_QQ,

				ISNULL(t.NumberGame_Call,0) NumberGame_Call,
				ISNULL(t.NumberGame_Email,0) NumberGame_Email,
				ISNULL(t.NumberGame_MSN,0) NumberGame_MSN,
				ISNULL(t.NumberGame_Skype,0) NumberGame_Skype,
				ISNULL(t.NumberGame_LiveChat,0) NumberGame_LiveChat,
				ISNULL(t.NumberGame_NA,0) NumberGame_NA,
				ISNULL(t.NumberGame_Yahoo,0) NumberGame_Yahoo,
				ISNULL(t.NumberGame_WeChat,0) NumberGame_WeChat,
				ISNULL(t.NumberGame_Line,0) NumberGame_Line,
				ISNULL(t.NumberGame_WhatsApp,0) NumberGame_WhatsApp,
				ISNULL(t.NumberGame_QQ,0) NumberGame_QQ,

				ISNULL(t.Bet2_Call,0) Bet2_Call,
				ISNULL(t.Bet2_Email,0) Bet2_Email,
				ISNULL(t.Bet2_MSN,0) Bet2_MSN,
				ISNULL(t.Bet2_Skype,0) Bet2_Skype,
				ISNULL(t.Bet2_LiveChat,0) Bet2_LiveChat,
				ISNULL(t.Bet2_NA,0) Bet2_NA,
				ISNULL(t.Bet2_Yahoo,0) Bet2_Yahoo,
				ISNULL(t.Bet2_WeChat,0) Bet2_WeChat,
				ISNULL(t.Bet2_Line,0) Bet2_Line,
				ISNULL(t.Bet2_WhatsApp,0) Bet2_WhatsApp,
				ISNULL(t.Bet2_QQ,0) Bet2_QQ,
				
				ISNULL(t.LiveCS_Call,0) LiveCS_Call,
				ISNULL(t.LiveCS_Email,0) LiveCS_Email,
				ISNULL(t.LiveCS_MSN,0) LiveCS_MSN,
				ISNULL(t.LiveCS_Skype,0) LiveCS_Skype,
				ISNULL(t.LiveCS_LiveChat,0) LiveCS_LiveChat,
				ISNULL(t.LiveCS_NA,0) LiveCS_NA,
				ISNULL(t.LiveCS_Yahoo,0) LiveCS_Yahoo,
				ISNULL(t.LiveCS_WeChat,0) LiveCS_WeChat,
				ISNULL(t.LiveCS_Line,0) LiveCS_Line,
				ISNULL(t.LiveCS_WhatsApp,0) LiveCS_WhatsApp,
				ISNULL(t.LiveCS_QQ,0) LiveCS_QQ,				
				
				ISNULL(t.MiniGame_Call,0) MiniGame_Call,
				ISNULL(t.MiniGame_Email,0) MiniGame_Email,
				ISNULL(t.MiniGame_MSN,0) MiniGame_MSN,
				ISNULL(t.MiniGame_Skype,0) MiniGame_Skype,
				ISNULL(t.MiniGame_LiveChat,0) MiniGame_LiveChat,
				ISNULL(t.MiniGame_NA,0) MiniGame_NA,
				ISNULL(t.MiniGame_Yahoo,0) MiniGame_Yahoo,
				ISNULL(t.MiniGame_WeChat,0) MiniGame_WeChat,
				ISNULL(t.MiniGame_Line,0) MiniGame_Line,
				ISNULL(t.MiniGame_WhatsApp,0) MiniGame_WhatsApp,
				ISNULL(t.MiniGame_QQ,0) MiniGame_QQ,
				
				ISNULL(t.Poker_Call,0) Poker_Call,
				ISNULL(t.Poker_Email,0) Poker_Email,
				ISNULL(t.Poker_MSN,0) Poker_MSN,
				ISNULL(t.Poker_Skype,0) Poker_Skype,
				ISNULL(t.Poker_LiveChat,0) Poker_LiveChat,
				ISNULL(t.Poker_NA,0) Poker_NA,
				ISNULL(t.Poker_Yahoo,0) Poker_Yahoo,
				ISNULL(t.Poker_WeChat,0) Poker_WeChat,
				ISNULL(t.Poker_Line,0) Poker_Line,
				ISNULL(t.Poker_WhatsApp,0) Poker_WhatsApp,
				ISNULL(t.Poker_QQ,0) Poker_QQ
		FROM @category c 
			LEFT JOIN @tmp t ON c.MaincategoryId = t.MaincategoryID
		ORDER BY MaincategoryID
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CasinoStatistics] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CasinoStatistics] TO [vnteam]
