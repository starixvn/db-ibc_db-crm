/*<info serverAlias="DBCRM-bodb_CRM" selecters="wsv_nap" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_GetNotifyThresholdCWL](
	@Environment VARCHAR(50)
)
RETURNS TABLE
AS
/*
	Created: 20250930@Dave
	Task: Get the threshold settings for CWL notification
	DB: DBCRM/bodb_CRM

	Revisions:
		- 20250929@Dave: CWL - Headline requests only trigger notifications under specific settings [RedmineId: #239736]
		
	Parameter's Explaination:
		- @Environment: 'LIVE' or 'UAT'
	Developer's Notes:
		- The HeadlineId 9727510 : TP
		- The CasinoType: 0: RNG Games, 1: RNG Casino, 2: Live Casino
		- The LosingThreshold and WinningThreshold are in RM currency.
*/
RETURN 

    SELECT 
        HeadlineId,
        CasinoType,
        LosingThreshold,
        WinningThreshold
    FROM (VALUES
        (9727510, 0, -50000, 50000, 0)/*TP*/
        ,(9727510, 1, -50000, 50000, 0)

		/*FOR TESTING*/
        ,(23003140, 1, -1000, 1000, 0)/*SupertestTE01*/
        ,(23003140, 0, -1000, 1000, 0)

        ,(14521687, 1, -5000, 5000, 1)/*SuperTest91*/
        ,(14521687, 0, -5000, 5000, 1)
        ,(1176070, 1, -50000, 50000, 1)/*SuperTest1*/
        ,(1176070, 0, -50000, 50000, 1)
    ) AS Thresholds (HeadlineId, CasinoType, LosingThreshold, WinningThreshold, IsTest)
	WHERE IsTest <= CASE WHEN @Environment = 'LIVE' THEN 0 ELSE 1 END;

GO	
	
