/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
USE [bodb02]

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Acc_CRM_Chatbot_RebateRetention_Sel]
	@LastLogSID XML
	,@BatchSize INT = 1
	,@NewLogSID XML = '' OUTPUT
AS
/*
    Created: 20241022@Virgil
    DB: DBAGE-bodb02
    Task: CRM - ChatBot - Import RebateAndRetention Notification

    Revisions:
        - 20241022@Virgil: Initialize SP [RedmineID: #210688]

	 Param's Explanation:
        - @XmlData: 
		<root>
			<r LastLogSID="71" SiteDBGroupId="3" ListPendingSIDs="84,85,86"/>
			<r LastLogSID="1" SiteDBGroupId="4" ListPendingSIDs=""/>
		</root>

	/*
	DECLARE @XMLOutput XML;
	EXEC [dbo].[Acc_CRM_Chatbot_RebateRetention_Sel] @LastLogSID = '<root>
																		<r LastLogSID="71" SiteDBGroupId="3" ListPendingSIDs="84,85,86"/>
																		<r LastLogSID="1" SiteDBGroupId="4" ListPendingSIDs=""/>
																	</root>'
													, @NewLogSID  = @XMLOutput OUTPUT
	SELECT @XMLOutput AS XMLOutput
	*/
*/
BEGIN

	SET NOCOUNT ON;

	-------------------------
    -- Parse XML Log data --
    CREATE TABLE #tmpXMLData (
        LastLogSID		SMALLINT,
        SiteDBGroupId	SMALLINT,
        ListPendingSIDs VARCHAR(MAX),
		NewLogSID	SMALLINT
    )
    INSERT INTO #tmpXMLData (LastLogSID, SiteDBGroupId, ListPendingSIDs)
    SELECT
        t.c.value('@LastLogSID', 'SMALLINT')				AS LastLogSID,
        t.c.value('@SiteDBGroupId', 'SMALLINT')				AS SiteDBGroupId,
        t.c.value('@ListPendingSIDs', 'VARCHAR(MAX)')		AS ListPendingSIDs
    FROM @LastLogSID.nodes('root/r') t(c)
    OPTION (OPTIMIZE FOR (@LastLogSID = NULL))


	CREATE TABLE #checkSID (
		[SID]		SMALLINT,
		SiteDBGroupID  SMALLINT,
		ProgramId	SMALLINT,
		StatusId	TINYINT,
		SourceType	BIT		-- *Condition get SIDs: 0 - get from ListPendingSIDs; 1 - get from LastLogSID*
    )
	--+ Priorly insert data from ListPendingSIDs for checking first
	INSERT INTO #checkSID
	SELECT ss.[SID],
			ss.SiteDBGroupID,
			ss.ProgramId,
			ss.StatusId,
			0 AS SourceType
	FROM dbo.SabaProgramStatus ss WITH (NOLOCK) 
	JOIN #tmpXMLData t
		ON t.SiteDBGroupId = ss.SiteDBGroupID
	CROSS APPLY (SELECT value AS [SID]
				 FROM STRING_SPLIT(t.ListPendingSIDs, ',')
				 WHERE value = ss.[SId]) p

	--+ Checking data from ListPendingSIDs are available or not
	IF NOT EXISTS (SELECT 1 FROM #checkSID WHERE StatusId = 2 AND SourceType = 0) 
	BEGIN
		-- Delete data ListPendingSIDs (no need care ListPendingSIDs)
		DELETE FROM #checkSID
		
		-- Insert data from LastLogSID for checking next (SourceType 1)
		INSERT INTO #checkSID
		SELECT DISTINCT 
				ss.[SID],
				ss.SiteDBGroupID,
				ss.ProgramId,
				ss.StatusId,
				1 AS SourceType
		FROM dbo.SabaProgramStatus ss WITH (NOLOCK) 
		JOIN dbo.SabaWalletTicket swt WITH (NOLOCK) 
			ON swt.SId = ss.SId
			AND swt.ProgramId = ss.ProgramId
			AND swt.SiteDBGroupID = ss.SiteDBGroupID
		JOIN #tmpXMLData t
			ON t.SiteDBGroupId = ss.SiteDBGroupID
		WHERE ss.SId > t.LastLogSID 
			AND swt.Srecommend IS NOT NULL
			AND swt.Srecommend <> 0

	END

	--+ Insert MinSID with Status 2 into #tmpXMLData
	;WITH 
		MinSID AS (
			SELECT SiteDBGroupID, MIN([SID]) MinSID
			FROM #checkSID
			WHERE StatusId = 2
			GROUP BY SiteDBGroupID
	)
	UPDATE A
	SET A.NewLogSID = B.MinSID
	FROM #tmpXMLData A
	JOIN MinSID B
		ON A.SiteDBGroupId = B.SiteDBGroupID


	--+ Update new ListPendingSIDs XML from each SourceType
	IF EXISTS (SELECT 1 FROM #checkSID WHERE StatusId = 2 AND SourceType = 0) 
	BEGIN
		-- SIDs from ListPendingSIDs
		;WITH 
			StringAgg AS (
				SELECT B.SiteDBGroupID, STRING_AGG(B.SID,',') WITHIN GROUP (ORDER BY B.SID ASC) AS NewPendingList
				FROM #tmpXMLData A
				INNER JOIN #checkSID B 
					ON A.SiteDBGroupId = B.SiteDBGroupID
				WHERE A.NewLogSID <> B.SID
				GROUP BY B.SiteDBGroupID
			)
		UPDATE X
		SET ListPendingSIDs = NewPendingList
		FROM #tmpXMLData X
		JOIN StringAgg Y
			ON X.SiteDBGroupId = Y.SiteDBGroupID
	END
	ELSE IF EXISTS (SELECT 1 FROM #checkSID WHERE StatusId = 2 AND SourceType = 1) 
	BEGIN
		-- SIDs from LastLogSID
		;WITH 
			StringAgg AS (
				SELECT X.SiteDBGroupId, STRING_AGG(Y.SID, ',') WITHIN GROUP ( ORDER BY Y.SID ASC) AS PendingSIDs
				FROM #tmpXMLData X
				JOIN #checkSID Y
					ON X.SiteDBGroupId = Y.SiteDBGroupID
				WHERE X.LastLogSID < Y.SID AND Y.SID < X.NewLogSID
					AND Y.StatusId = 1
				GROUP BY X.SiteDBGroupId
			)
		UPDATE X
		SET ListPendingSIDs = TRIM(',' FROM CONCAT(ListPendingSIDs,',', Y.PendingSIDs))
		FROM #tmpXMLData X
		JOIN StringAgg Y
			ON X.SiteDBGroupId = Y.SiteDBGroupID
	END

	--+ Update LastLSId from NewLogSID (MinSID)
	UPDATE #tmpXMLData 
	SET LastLogSID = NewLogSID 
	WHERE NewLogSID IS NOT NULL

	--+ OUTPUT @NewLogSID
	SELECT @NewLogSID = (
		SELECT LastLogSID, SiteDBGroupId, ListPendingSIDs
		FROM #tmpXMLData 
		FOR XML RAW('r'), ROOT('root')
	)

	--+ Create temp FinalData to get data and gather other neccessary infos
	CREATE TABLE #FinalData (
		CustId			INT,
		Recommend		INT,
		Mrecommend		INT,
		Srecommend		INT,
		[SID]			INT,
		SiteDBGroupID	INT, 
		StatusId		TINYINT,
		Amount			MONEY,
		CurrencyID		INT,
		IsTest			BIT
    )
	INSERT INTO #FinalData
	SELECT swt.CustId,
			swt.Recommend,
			swt.Mrecommend,
			swt.Srecommend,
			swt.[SID],
			swt.SiteDBGroupID, 
			ss.StatusId,
			swt.Amount,
			swt.CurrencyID,
			CASE 
				WHEN swt.CurrencyID = 20 THEN 1 
				ELSE 0 
			END AS IsTest
	FROM dbo.SabaWalletTicket swt WITH (NOLOCK) 
	JOIN #checkSID ss WITH (NOLOCK) 
		ON swt.SId = ss.SId
		AND swt.ProgramId = ss.ProgramId
		AND swt.SiteDBGroupID = ss.SiteDBGroupID
	JOIN #tmpXMLData t
		ON t.SiteDBGroupId = swt.SiteDBGroupID
		AND t.NewLogSID = swt.[SId]
	WHERE (1 = 1)
		AND swt.Srecommend IS NOT NULL
		AND swt.Srecommend <> 0

	--+ Cause 1 SID has many TransID so we sum up total amount
	;WITH
		CTE_Data AS (
			SELECT SiteDBGroupID,
					CustId,
					Recommend,
					Mrecommend,
					Srecommend,
					CurrencyID,
					IsTest,
					SUM(Amount) TotalAmount
			FROM #FinalData 
			WHERE StatusId = 2
			GROUP BY SiteDBGroupID,
					CustId,
					Recommend,
					Mrecommend,
					Srecommend,
					CurrencyID,
					IsTest
	)
	SELECT cd.SiteDBGroupID, 
			cd.CustId,
			cd.Recommend,
			cd.Mrecommend,
			cd.Srecommend,
			CONCAT(cus.username,' ', REPLACE(FORMAT(cd.TotalAmount, 'N'),'.00',''), ' ', e.currency) AS AffectedMember,
			cd.IsTest
	FROM CTE_Data cd
	JOIN dbo.Exchange e WITH (NOLOCK) 
		ON e.ExchangeId = cd.CurrencyID
	JOIN dbo.Customer cus (NOLOCK)
		ON cus.custid = cd.CustID
		AND cus.roleid = 1
		AND cus.srecommend IS NOT NULL


	DROP TABLE #tmpXMLData;
	DROP TABLE #checkSID;
	DROP TABLE #FinalData;
END
GO
