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
-- Rule to migrate | ------------------------------------------------- |
--                 | >> Phone                     [SettingValue=Phone] |
--                 |    PhoneCountryCode                               |
--                 |    PhoneAreaCode                                  |
--                 |    Phone2                                         |
--                 |    Phone2CountryCode                              |
--                 |    Phone2AreaCode                                 |
--                 |    Phone3                                         |
--                 |    Phone3CountryCode                              |
--                 |    Phone3AreaCode                                 |
--                 |    MobilePhone                                    |
--                 |    MobilePhoneCountryCode                         |
--                 |    MobilePhoneAreaCode                            |
--                 | ------------------------------------------------- |
--                 | >> Email                     [SettingValue=Email] |
--                 | ------------------------------------------------- |
--                 | >> Skype                     [SettingValue=Skype] |
--                 | ------------------------------------------------- |
--                 | >> MSN                    [SettingValue=Telegram] |
--                 | ------------------------------------------------- |
--                 | >> WhatsApp               [SettingValue=WhatsApp] |
--                 | ------------------------------------------------- |
--                 | >> Line                       [SettingValue=Line] |
--                 | ------------------------------------------------- |
--                 | >> WeChat                   [SettingValue=WeChat] |
--                 | ------------------------------------------------- |
--                 | >> Yahoo                  [SettingValue=Letstalk] |
--                 | ------------------------------------------------- |
--                 | >> BBM                        [SettingValue=Zalo] |

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

DECLARE @SettingID_Phone INT
SELECT  @SettingID_Phone = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Phone'
DECLARE @SettingID_Email INT
SELECT  @SettingID_Email = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Email'
DECLARE @SettingID_Skype INT
SELECT  @SettingID_Skype = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Skype'
DECLARE @SettingID_Telegram INT
SELECT  @SettingID_Telegram = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Telegram'
DECLARE @SettingID_WhatsApp INT
SELECT  @SettingID_WhatsApp = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'WhatsApp'
DECLARE @SettingID_Line INT
SELECT  @SettingID_Line = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Line'
DECLARE @SettingID_WeChat   INT
SELECT  @SettingID_WeChat = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'WeChat'
DECLARE @SettingID_Letstalk INT
SELECT  @SettingID_Letstalk = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Letstalk'
DECLARE @SettingID_Zalo INT
SELECT  @SettingID_Zalo = SettingID FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Zalo'

-- Run the loop to process data
WHILE (1=1)
BEGIN
    -- + Check to break the loop
    SELECT @count = COUNT(1)
    FROM #tmpCustomerFull
    WHERE isProcessed = 0

    IF (@count = 0) BREAK

    -- + Get batch of data
    TRUNCATE TABLE #tmpCustomerBatch
    
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
    --   --> Phone                  >> [SettingValue=Phone]
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
    ;WITH
    CTE_phone_initial AS (
        SELECT CustID,
               (ISNULL(PhoneCountryCode,'')       + ISNULL(PhoneAreaCode,'')       + ISNULL(Phone,''))       Phone,
               (ISNULL(Phone2CountryCode,'')      + ISNULL(Phone2AreaCode,'')      + ISNULL(Phone2,''))      Phone2,
               (ISNULL(Phone3CountryCode,'')      + ISNULL(Phone3AreaCode,'')      + ISNULL(Phone3,''))      Phone3,
               (ISNULL(MobilePhoneCountryCode,'') + ISNULL(MobilePhoneAreaCode,'') + ISNULL(MobilePhone,'')) MobilePhone
        FROM #tmpCustomerBatch
        WHERE (ISNULL(PhoneCountryCode,'')       + ISNULL(PhoneAreaCode,'')       + ISNULL(Phone,''))       <> '' OR
              (ISNULL(Phone2CountryCode,'')      + ISNULL(Phone2AreaCode,'')      + ISNULL(Phone2,''))      <> '' OR
              (ISNULL(Phone3CountryCode,'')      + ISNULL(Phone3AreaCode,'')      + ISNULL(Phone3,''))      <> '' OR
              (ISNULL(MobilePhoneCountryCode,'') + ISNULL(MobilePhoneAreaCode,'') + ISNULL(MobilePhone,'')) <> ''
    ),
    CTE_phone_connect0102 AS (
        SELECT CustID,
               (Phone + CASE WHEN Phone<>'' AND Phone2<>'' THEN ',' ELSE '' END + Phone2) Connect_Phone_0102,
               Phone3,
               MobilePhone
        FROM CTE_phone_initial
    ),
    CTE_phone_connect010203 AS (
        SELECT CustID,
               (Connect_Phone_0102 + CASE WHEN Connect_Phone_0102<>'' AND Phone3<>'' THEN ',' ELSE '' END + Phone3) Connect_Phone_010203,
               MobilePhone
        FROM CTE_phone_connect0102
    ),
    CTE_phone_final AS (
        SELECT CustID,
               (Connect_Phone_010203 + CASE WHEN Connect_Phone_010203<>'' AND MobilePhone<>'' THEN ',' ELSE '' END + MobilePhone) Connect_Phone_010203mobile
        FROM CTE_phone_connect010203
    )
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID,
           @SettingID_Phone CommunicationID,
           Connect_Phone_010203mobile CommunicationValue
    FROM CTE_phone_final
    --   --> Email >> [SettingValue=Email]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID           CustID,
           @SettingID_Email CommunicationID,
           Email            CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(Email, '') <> ''
    --   --> Skype >> [SettingValue=Skype]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID           CustID,
           @SettingID_Skype CommunicationID,
           Skype            CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(Skype, '') <> ''
    --   --> MSN >> [SettingValue=Telegram]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID              CustID,
           @SettingID_Telegram CommunicationID,
           MSN                 CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(MSN, '') <> ''
    --   --> WhatsApp >> [SettingValue=WhatsApp]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID              CustID,
           @SettingID_WhatsApp CommunicationID,
           WhatsApp            CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(WhatsApp, '') <> ''
    --   --> Line >> [SettingValue=Line]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID          CustID,
           @SettingID_Line CommunicationID,
           Line            CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(Line, '') <> ''
    --   --> WeChat >> [SettingValue=WeChat]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID            CustID,
           @SettingID_WeChat CommunicationID,
           WeChat            CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(WeChat, '') <> ''
    --   --> Yahoo >> [SettingValue=Letstalk]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID              CustID,
           @SettingID_Letstalk CommunicationID,
           Yahoo               CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(Yahoo, '') <> ''
    --   --> BBM >> [SettingValue=Zalo]
    INSERT INTO bodb_CRM.dbo.crmCustomerNewCommunicationTool (
        CustID,
        CommunicationID,
        CommunicationValue
    )
    SELECT CustID          CustID,
           @SettingID_Zalo CommunicationID,
           BBM             CommunicationValue
    FROM #tmpCustomerBatch
    WHERE ISNULL(BBM, '') <> ''

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