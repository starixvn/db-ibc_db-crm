/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240320@Ned.Le
DB: DBCRM.bodb_CRM
Task: Migrate data from crmCustomer to crmCustomerNewCommunicationTool
*/


USE bodb_CRM
GO


-------
-- 1 --
-- Get list of custid need to migrate data

CREATE TABLE #tmpCustomerFull (
    CustID                 INT,
    UserName               NVARCHAR(200),
    Phone                  NVARCHAR(50),
    PhoneCountryCode       NVARCHAR(20),
    PhoneAreaCode          NVARCHAR(20),
    Phone2                 NVARCHAR(50),
    Phone2CountryCode      NVARCHAR(20),
    Phone2AreaCode         NVARCHAR(20),
    Phone3                 NVARCHAR(50),
    Phone3CountryCode      NVARCHAR(20),
    Phone3AreaCode         NVARCHAR(20),
    MobilePhone            NVARCHAR(50),
    MobilePhoneCountryCode NVARCHAR(20),
    MobilePhoneAreaCode    NVARCHAR(20),
    Email                  NVARCHAR(254),
    Skype                  NVARCHAR(100),
    MSN                    NVARCHAR(100),
    WhatsApp               NVARCHAR(100),
    Line                   NVARCHAR(100),
    WeChat                 NVARCHAR(100),
    Yahoo                  NVARCHAR(100),
    BBM                    NVARCHAR(100),
    isProcessed            BIT DEFAULT 0
)

INSERT INTO #tmpCustomerFull (
    CustID,
    UserName,
    Phone,
    PhoneCountryCode,
    PhoneAreaCode,
    Phone2,
    Phone2CountryCode,
    Phone2AreaCode,
    Phone3,
    Phone3CountryCode,
    Phone3AreaCode,
    MobilePhone,
    MobilePhoneCountryCode,
    MobilePhoneAreaCode,
    Email,
    Skype,
    MSN,
    WhatsApp,
    Line,
    WeChat,
    Yahoo,
    BBM
)
SELECT cc.CustID,
       cc.UserName,
       cc.Phone,
       cc.PhoneCountryCode,
       cc.PhoneAreaCode,
       cc.Phone2,
       cc.Phone2CountryCode,
       cc.Phone2AreaCode,
       cc.Phone3,
       cc.Phone3CountryCode,
       cc.Phone3AreaCode,
       cc.MobilePhone,
       cc.MobilePhoneCountryCode,
       cc.MobilePhoneAreaCode,
       cc.Email,
       cc.Skype,
       cc.MSN,
       cc.WhatsApp,
       cc.Line,
       cc.WeChat,
       cc.Yahoo,
       cc.BBM
FROM bodb_CRM.dbo.crmCustomer cc WITH (NOLOCK)
WHERE cc.CustID NOT IN (SELECT custid FROM bodb02.dbo.custAccount ca WITH (NOLOCK) WHERE ca.IsGroupHeadLine = 1)

CREATE CLUSTERED INDEX CIX_CustID ON #tmpCustomerFull(CustID)


-------
-- 2 --
-- Process to migrate data
-- Rule to migrate ----------------------------------------------------
--                 >> Phone                  >> SettingID=49001 [Phone]
--                    PhoneCountryCode
--                    PhoneAreaCode
--                    Phone2
--                    Phone2CountryCode
--                    Phone2AreaCode
--                    Phone3
--                    Phone3CountryCode
--                    Phone3AreaCode
--                    MobilePhone
--                    MobilePhoneCountryCode
--                    MobilePhoneAreaCode
--                 -------------------------------------------------------
--                 >> Email                  >> SettingID=49002    [Email]
--                 -------------------------------------------------------
--                 >> Skype                  >> SettingID=49003    [Skype]
--                 -------------------------------------------------------
--                 >> MSN                    >> SettingID=49007 [Telegram]
--                 -------------------------------------------------------
--                 >> WhatsApp               >> SettingID=49006 [WhatsApp]
--                 -------------------------------------------------------
--                 >> Line                   >> SettingID=49005     [Line]
--                 -------------------------------------------------------
--                 >> WeChat                 >> SettingID=49004   [WeChat]
--                 -------------------------------------------------------
--                 >> Yahoo                  >> SettingID=49000 [Letstalk]
--                 -------------------------------------------------------
--                 >> BBM                    >> SettingID=49xxx     [Zalo]

-- Create temp table
CREATE TABLE #tmpCustomerBatch (
    CustID                 INT,
    UserName               NVARCHAR(200),
    Phone                  NVARCHAR(50),
    PhoneCountryCode       NVARCHAR(20),
    PhoneAreaCode          NVARCHAR(20),
    Phone2                 NVARCHAR(50),
    Phone2CountryCode      NVARCHAR(20),
    Phone2AreaCode         NVARCHAR(20),
    Phone3                 NVARCHAR(50),
    Phone3CountryCode      NVARCHAR(20),
    Phone3AreaCode         NVARCHAR(20),
    MobilePhone            NVARCHAR(50),
    MobilePhoneCountryCode NVARCHAR(20),
    MobilePhoneAreaCode    NVARCHAR(20),
    Email                  NVARCHAR(254),
    Skype                  NVARCHAR(100),
    MSN                    NVARCHAR(100),
    WhatsApp               NVARCHAR(100),
    Line                   NVARCHAR(100),
    WeChat                 NVARCHAR(100),
    Yahoo                  NVARCHAR(100),
    BBM                    NVARCHAR(100)
)

CREATE CLUSTERED INDEX CIX_CustID ON #tmpCustomerBatch(CustID)

-- Declare variables
DECLARE @count INT = 0
DECLARE @batch INT = 1000

-- Run the loop to process data
WHILE (1=1)
BEGIN
    -- + Check to break the loop
    SELECT @count = COUNT(1)
    FROM #tmpCustomerFull
    WHERE isProcessed = 0

    IF (@count = 0) BREAK

    -- + Get batch of data
    INSERT INTO #tmpCustomerBatch (
        CustID,
        UserName,
        Phone,
        PhoneCountryCode,
        PhoneAreaCode,
        Phone2,
        Phone2CountryCode,
        Phone2AreaCode,
        Phone3,
        Phone3CountryCode,
        Phone3AreaCode,
        MobilePhone,
        MobilePhoneCountryCode,
        MobilePhoneAreaCode,
        Email,
        Skype,
        MSN,
        WhatsApp,
        Line,
        WeChat,
        Yahoo,
        BBM
    )
    SELECT TOP(@batch)
           CustID,
           UserName,
           Phone,
           PhoneCountryCode,
           PhoneAreaCode,
           Phone2,
           Phone2CountryCode,
           Phone2AreaCode,
           Phone3,
           Phone3CountryCode,
           Phone3AreaCode,
           MobilePhone,
           MobilePhoneCountryCode,
           MobilePhoneAreaCode,
           Email,
           Skype,
           MSN,
           WhatsApp,
           Line,
           WeChat,
           Yahoo,
           BBM
    FROM #tmpCustomerFull
    WHERE isProcessed = 0
    ORDER BY CustID

    -- + Delete data before migrating to prevent duplicate data
    DELETE c
    FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool c WITH (UPDLOCK, TABLOCK)
    WHERE c.CustID IN (SELECT CustID FROM #tmpCustomerBatch)

    -- + Migrate data
    --   --> Phone                  >> SettingID=49001 [Phone]
    --       PhoneCountryCode
    --       PhoneAreaCode
    --       Phone2
    --       Phone2CountryCode
    --       Phone2AreaCode
    --       Phone3
    --       Phone3CountryCode
    --       Phone3AreaCode
    --       MobilePhone
    --       MobilePhoneCountryCode
    --       MobilePhoneAreaCode
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID CustID,
           49001  CommunicationID,
           (ISNULL(Phone,'')+ISNULL(PhoneCountryCode,'')+ISNULL(PhoneAreaCode,'')    + ',' +
            ISNULL(Phone2,'')+ISNULL(Phone2CountryCode,'')+ISNULL(Phone2AreaCode,'') + ',' +
            ISNULL(Phone3,'')+ISNULL(Phone3CountryCode,'')+ISNULL(Phone3AreaCode,'') + ',' +
            ISNULL(MobilePhone,'')+ISNULL(MobilePhoneCountryCode,'')+ISNULL(MobilePhoneAreaCode,'')) CommunicationValue
    FROM #tmpCustomerBatch
    --   --> Email >> SettingID=49002 [Email]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID CustID,
           49002  CommunicationID,
           Email  CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(Email, '') <> ''
    --   --> Skype >> SettingID=49003 [Skype]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID CustID,
           49003  CommunicationID,
           Skype  CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(Skype, '') <> ''
    --   --> MSN >> SettingID=49007 [Telegram]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID CustID,
           49007  CommunicationID,
           MSN    CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(MSN, '') <> ''
    --   --> WhatsApp >> SettingID=49006 [WhatsApp]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID   CustID,
           49006    CommunicationID,
           WhatsApp CommunicationValue
    FROM #tmpCustomerBatch
    --   --> Line >> SettingID=49005 [Line]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID CustID,
           49005  CommunicationID,
           Line   CommunicationValue
    FROM #tmpCustomerBatch
    --   --> WeChat >> SettingID=49004 [WeChat]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID CustID,
           49004  CommunicationID,
           WeChat CommunicationValue
    FROM #tmpCustomerBatch
    --   --> Yahoo >> SettingID=49000 [Letstalk]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID CustID,
           49000  CommunicationID,
           Yahoo  CommunicationValue
    FROM #tmpCustomerBatch
    --   --> BBM >> SettingID=49xxx [Zalo]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID CustID,
           490    CommunicationID,
           BBM    CommunicationValue
    FROM #tmpCustomerBatch

    -- + Update setting to continue the loop
    UPDATE f
    SET f.isProcessed = 1
    FROM #tmpCustomerFull f
    WHERE EXISTS (SELECT TOP 1 1 FROM #tmpCustomerBatch b WHERE b.CustID = f.CustID)
          AND f.isProcessed = 0
END


-------
-- 3 --
-- Drop temp table

DROP TABLE #tmpCustomerFull
DROP TABLE #tmpCustomerBatch