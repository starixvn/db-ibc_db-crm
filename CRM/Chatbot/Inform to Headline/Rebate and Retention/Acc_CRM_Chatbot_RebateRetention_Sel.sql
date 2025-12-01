/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
		- 20250324@Virgil: CRM - hotfix displaying Currency Code instead of Currency Name [RedmineID: #221391]
		- 20251201@Dave: CRM - Notification for Rebate and Retention - Implement Batch-Based Processing [RedmineID: #245494]

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

	DECLARE @RowProcessing INT = 0;
	-------------------------
    -- Parse XML Log data --
    CREATE TABLE #tmpXMLData (
        LastLogSID		INT,
        SiteDBGroupId	SMALLINT,
        ListPendingSIDs VARCHAR(MAX)
    )
    INSERT INTO #tmpXMLData (LastLogSID, SiteDBGroupId, ListPendingSIDs)
    SELECT
        t.c.value('@LastLogSID', 'INT')						AS LastLogSID,
        t.c.value('@SiteDBGroupId', 'SMALLINT')				AS SiteDBGroupId,
        t.c.value('@ListPendingSIDs', 'VARCHAR(MAX)')		AS ListPendingSIDs
    FROM @LastLogSID.nodes('root/r') t(c)
    OPTION (OPTIMIZE FOR (@LastLogSID = NULL))

	CREATE TABLE #checkSID (
		[SID]		INT,
		SiteDBGroupID  SMALLINT,
		ProgramId	SMALLINT,
		StatusId	TINYINT,
		IsProccess	BIT DEFAULT(0) -- 0: Not Processed, 1: Processed
    )
	
	--+ Priorly insert data from ListPendingSIDs for checking first
	;WITH PendingSIDs AS (
		SELECT t.SiteDBGroupId,
				CAST(ps.value AS INT) AS SID_Value
		FROM #tmpXMLData t
		CROSS APPLY STRING_SPLIT(t.ListPendingSIDs, ',') ps
		WHERE ps.value <> ''
	)
	INSERT INTO #checkSID ([SID], SiteDBGroupID, ProgramId, StatusId)
	SELECT ss.[SID],
			p.SiteDBGroupID,
			ss.ProgramId,
			ss.StatusId
	FROM dbo.SabaProgramStatus ss WITH (NOLOCK)
		INNER JOIN PendingSIDs p
			ON p.SID_Value = ss.[SID]
			AND p.SiteDBGroupId = ss.SiteDBGroupID;

	SELECT @RowProcessing = COUNT(1) FROM #checkSID WHERE StatusId = 2;

	--+ If RowProcessing < BatchSize, continue to get SIDs from LastLogSID
	IF (@BatchSize > @RowProcessing)
	BEGIN

		INSERT INTO #checkSID ([SID], SiteDBGroupID, ProgramId, StatusId)
		SELECT /*TOP (@BatchSize - @RowProcessing)*/
			ss.[SID],
			t.SiteDBGroupID,
			ss.ProgramId,
			ss.StatusId
		FROM dbo.SabaProgramStatus ss WITH (NOLOCK)
			INNER JOIN #tmpXMLData t 
				ON t.SiteDBGroupID = ss.SiteDBGroupID
		WHERE ss.SId > t.LastLogSID
			AND EXISTS (
				SELECT TOP(1) 1
				FROM dbo.SabaWalletTicket swt WITH (NOLOCK)
				WHERE swt.SId = ss.SId
					AND swt.ProgramId = ss.ProgramId
					AND swt.SiteDBGroupID = ss.SiteDBGroupID
					AND swt.Srecommend IS NOT NULL
					AND swt.Srecommend <> 0
			)
		/*ORDER BY ss.[SID] ASC;*/

	END

	--+ Mark processed SIDs
	;WITH TMP_Processed AS (
		SELECT [SID], SiteDBGroupID, ROW_NUMBER() OVER (ORDER BY [SID] ASC) AS RN -- Batch Size by SID, do not care about SiteDBGroupID here
		FROM #checkSID
		WHERE StatusId = 2
	)
	UPDATE c
	SET c.IsProccess = 1
	FROM #checkSID c
		INNER JOIN TMP_Processed p
			ON c.[SID] = p.[SID]
			AND c.SiteDBGroupID = p.SiteDBGroupID
	WHERE p.RN <= @BatchSize;

	--+ Update LastLogSID from Max SID
	WITH TMP_LastLogSID AS(
		SELECT SiteDBGroupID, MAX([SID]) AS LastLogSID
		FROM #checkSID
		GROUP BY SiteDBGroupID
	)
	UPDATE a
	SET a.LastLogSID = b.LastLogSID
	FROM #tmpXMLData a
		INNER JOIN TMP_LastLogSID b
			ON a.SiteDBGroupID = b.SiteDBGroupID
	WHERE a.LastLogSID < b.LastLogSID;

	--+ Update ListPendingSIDs from remaining SIDs
	WITH TMP_ListPendingSIDs AS (
		SELECT 
			c.SiteDBGroupID,
			STRING_AGG(c.[SID], ',') WITHIN GROUP (ORDER BY c.[SID] ASC) AS PendingSIDs
		FROM #checkSID c
		WHERE c.IsProccess = 0
		GROUP BY c.SiteDBGroupID
	)
	UPDATE a
	SET a.ListPendingSIDs = ISNULL(b.PendingSIDs, '')
	FROM #tmpXMLData a
		LEFT JOIN TMP_ListPendingSIDs b
			ON a.SiteDBGroupID = b.SiteDBGroupID;


	--+ OUTPUT @NewLogSID
	SELECT @NewLogSID = (
		SELECT LastLogSID, SiteDBGroupId, ListPendingSIDs
		FROM #tmpXMLData 
		FOR XML RAW('r'), ROOT('root')
	);

	DELETE #checkSID
	WHERE IsProccess = 0;

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
	INSERT INTO #FinalData(CustId, Recommend, Mrecommend, Srecommend, [SID], SiteDBGroupID, StatusId, Amount, CurrencyID, IsTest)
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
	INNER JOIN #checkSID ss WITH (NOLOCK) 
		ON swt.ProgramId = ss.ProgramId
		AND swt.SId = ss.SId
		AND swt.SiteDBGroupID = ss.SiteDBGroupID
	WHERE (1 = 1)
		AND swt.Srecommend IS NOT NULL
		AND swt.Srecommend <> 0

	--+ Cause 1 SID has many TransID so we sum up total amount
	;WITH
		CTE_Data AS (
			SELECT [SID],
					SiteDBGroupID,
					CustId,
					Recommend,
					Mrecommend,
					Srecommend,
					CurrencyID,
					IsTest,
					SUM(Amount) TotalAmount
			FROM #FinalData
			GROUP BY SiteDBGroupID,
					CustId,
					Recommend,
					Mrecommend,
					Srecommend,
					CurrencyID,
					IsTest,
					[SID]
	)
	SELECT cd.[SID],
			cd.SiteDBGroupID, 
			cd.CustId,
			cd.Recommend,
			cd.Mrecommend,
			cd.Srecommend,
			CONCAT(cus.username,' ', REPLACE(FORMAT(cd.TotalAmount, 'N'),'.00',''), ' ', e.Code) AS AffectedMember,
			cd.IsTest, cus.roleid, cus.srecommend
	FROM CTE_Data cd
	INNER JOIN dbo.Exchange e WITH (NOLOCK) 
		ON e.ExchangeId = cd.CurrencyID
	INNER JOIN dbo.Customer cus (NOLOCK)
		ON cus.custid = cd.CustID
		AND cus.roleid = 1
		AND cus.srecommend IS NOT NULL
	ORDER BY cd.SiteDBGroupID ASC, cd.[SID] ASC;


	DROP TABLE #tmpXMLData;
	DROP TABLE #checkSID;
	DROP TABLE #FinalData;
END
GO
