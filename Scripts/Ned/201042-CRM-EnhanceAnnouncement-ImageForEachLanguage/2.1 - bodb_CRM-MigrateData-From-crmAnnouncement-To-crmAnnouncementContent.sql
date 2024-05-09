/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240325@Ned.Le
DB: DBCRM.bodb_CRM
Task: Migrate data from crmAnnouncement to crmAnnouncementContent
*/


USE bodb_CRM
GO


-------
-- 1 --
-- Get list of AnnouncementId need to migrate data

CREATE TABLE #tmpAnnouncementIdFull (AnnouncementId INT NOT NULL, isProcessed BIT DEFAULT 0)

INSERT INTO #tmpAnnouncementIdFull (AnnouncementId)
SELECT ac.AnnouncementId
FROM bodb_CRM.dbo.crmAnnouncementContent ac WITH (NOLOCK)
GROUP BY ac.AnnouncementId
ORDER BY ac.AnnouncementId

CREATE UNIQUE CLUSTERED INDEX CIX_AnnouncementId ON #tmpAnnouncementIdFull(AnnouncementId)


-------
-- 2 --
-- Process to migrate data


-- Create temp table
CREATE TABLE #tmpAnnouncementIdBatch (AnnouncementId INT NOT NULL)
CREATE CLUSTERED INDEX CIX_AnnouncementId ON #tmpAnnouncementIdBatch(AnnouncementId)

-- Declare variables
DECLARE @count INT = 0
DECLARE @batch INT = 500

-- Run the loop to process data
WHILE (1=1)
BEGIN
    -- + Check to break the loop
    SELECT @count = COUNT(1)
    FROM #tmpAnnouncementIdFull
    WHERE isProcessed = 0

    IF (@count = 0) BREAK

    -- + Get batch of data
    TRUNCATE TABLE #tmpAnnouncementIdBatch

    INSERT INTO #tmpAnnouncementIdBatch (AnnouncementId)
    SELECT TOP(@batch)
           AnnouncementId
    FROM #tmpAnnouncementIdFull
    WHERE isProcessed = 0
    ORDER BY AnnouncementId

    -- + Migrate data
    UPDATE ac
    SET ac.FileName = a.FileName
    FROM bodb_CRM.dbo.crmAnnouncementContent ac WITH (UPDLOCK, TABLOCK)
         INNER JOIN bodb_CRM.dbo.crmAnnouncement a WITH (NOLOCK) ON ac.AnnouncementId = a.AnnouncementId
    WHERE EXISTS (SELECT TOP 1 1 FROM #tmpAnnouncementIdBatch tmp WHERE tmp.AnnouncementId = ac.AnnouncementId)

    -- + Update setting to continue the loop
    UPDATE f
    SET f.isProcessed = 1
    FROM #tmpAnnouncementIdFull f
    WHERE EXISTS (SELECT TOP 1 1 FROM #tmpAnnouncementIdBatch b WHERE b.AnnouncementId = f.AnnouncementId)
          AND f.isProcessed = 0
END


-------
-- 3 --
-- Drop temp table

DROP TABLE #tmpAnnouncementIdFull
DROP TABLE #tmpAnnouncementIdBatch