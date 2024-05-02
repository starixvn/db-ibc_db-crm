/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewAccDetail_UpdHeadlineCompanyService @HeadlineID      INT,
                                                                   @CompanyServices NVARCHAR(MAX),
                                                                   @UserID          INT,
                                                                   @IP              VARCHAR(45)    = '',
                                                                   @ErrCode         INT            = 0  OUTPUT,
                                                                   @ErrMsg          NVARCHAR(4000) = '' OUTPUT
AS

/*
    Created: Ned.Le
    Date:    20231212
    Task:    Insert/Update/Delete company service of headline
    DB:      DBCRM.bodb_CRM

    Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

    Param's Explanation:
        @HeadlineID:         HeadlineID that its data be manipulated
        @CompanyServices: <ROOT>
                              <CompanyService CompanyServiceID="110000" IsOffered="1" CommunicationID="49000" CommunicationValue="letstalk01,letstalk02"/>
                              <CompanyService CompanyServiceID="110001" IsOffered="1" CommunicationID="49001" CommunicationValue="0919854789"/>
                              <CompanyService CompanyServiceID="110002" IsOffered="0" CommunicationID="" CommunicationValue=""/>
                              <CompanyService CompanyServiceID="110003" IsOffered="0" CommunicationID="" CommunicationValue=""/>
                              <CompanyService CompanyServiceID="110004" IsOffered="0" CommunicationID="" CommunicationValue=""/>
                          </ROOT>

    Example:
        DECLARE @CompanyServices_in NVARCHAR(MAX) = '<ROOT>
                                                         <CompanyService CompanyServiceID="110000" IsOffered="1" CommunicationID="49000" CommunicationValue="letstalk03"/>
                                                         <CompanyService CompanyServiceID="110001" IsOffered="1" CommunicationID="49001" CommunicationValue="0919854789"/>
                                                         <CompanyService CompanyServiceID="110002" IsOffered="0" CommunicationID="" CommunicationValue=""/>
                                                         <CompanyService CompanyServiceID="110003" IsOffered="1" CommunicationID="49002" CommunicationValue="mail01@gmail.com"/>
                                                         <CompanyService CompanyServiceID="110004" IsOffered="0" CommunicationID="" CommunicationValue=""/>
                                                     </ROOT>'
        DECLARE @ErrCode_out INT = 0
        DECLARE @ErrMsg_out NVARCHAR(4000) = ''
        EXEC bodb_CRM.dbo.Acc_CRM_NewAccDetail_UpdHeadlineCompanyService @HeadlineID      = 2088287,
                                                                         @CompanyServices = @CompanyServices_in,
                                                                         @UserID          = 8,
                                                                         @IP              = '10.0.0.4',
                                                                         @ErrCode         = @ErrCode_out OUTPUT,
                                                                         @ErrMsg          = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out ErrCode, @ErrMsg_out ErrMsg
*/

BEGIN

    SET NOCOUNT ON


    ---------------------------------------------------------------------
    -- Parse data from @CompanyServices to temp table #tmpCompanyServices

    DECLARE @iDoc INT
    EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @CompanyServices

    CREATE TABLE #tmpCompanyServices (
        CompanyServiceID   INT,
        isOffered          BIT,
        CommunicationID    INT,
        CommunicationValue NVARCHAR(200)
    )

    INSERT INTO #tmpCompanyServices (
        CompanyServiceID,
        isOffered,
        CommunicationID,
        CommunicationValue
    )
    SELECT ox.CompanyServiceID,
           ox.IsOffered,
           ox.CommunicationID,
           ox.CommunicationValue
    FROM OPENXML(@iDoc, '/ROOT/CompanyService', 1)
    WITH (CompanyServiceID   INT,
          IsOffered          BIT,
          CommunicationID    INT,
          CommunicationValue NVARCHAR(200)) AS ox


    -----------------------------------
    -- Get old value of Company Service

    CREATE TABLE #tmpCompanyServiceOldValue (
        HeadlineID         INT,
        CompanyServiceID   INT,
        CompanyServiceName NVARCHAR(1000),
        isOffered          VARCHAR(100),
        CommunicationID    INT,
        CommunicationTool  NVARCHAR(1000),
        CommunicationValue NVARCHAR(1000)
    )

    INSERT INTO #tmpCompanyServiceOldValue (
        HeadlineID,
        CompanyServiceID,
        CompanyServiceName,
        isOffered,
        CommunicationID,
        CommunicationTool,
        CommunicationValue
    )
    SELECT chc.HeadlineID                                       HeadlineID,
           chc.CompanyServiceID                                 CompanyServiceID,
           scs.SettingValue                                     CompanyServiceName,
           CASE WHEN chc.isOffered = 1 THEN 'Yes' ELSE 'No' END isOffered,
           chc.CommunicationID                                  CommunicationID,
           sc.SettingValue                                      CommunicationTool,
           chc.CommunicationValue                               CommunicationValue
    FROM bodb_CRM.dbo.crmCustomerHeadlineCompanyService chc WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmSetting scs WITH (NOLOCK) ON scs.SettingName = 'HeadlineCompanyService' AND chc.CompanyServiceID = scs.SettingID
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND chc.CommunicationID = sc.SettingID
    WHERE chc.HeadlineID = @HeadlineID
    OPTION (RECOMPILE)


    -----------------------------------
    -- Update value for Company Service

    BEGIN TRY    
        MERGE bodb_CRM.dbo.crmCustomerHeadlineCompanyService AS TARGET
        USING #tmpCompanyServices AS SOURCE
        ON TARGET.HeadlineID = @HeadlineID AND TARGET.CompanyServiceID = SOURCE.CompanyServiceID
        WHEN MATCHED THEN
            UPDATE SET TARGET.CompanyServiceID   = SOURCE.CompanyServiceID,
                       TARGET.isOffered          = SOURCE.isOffered,
                       TARGET.CommunicationID    = CASE WHEN SOURCE.CommunicationID = 0 THEN NULL ELSE SOURCE.CommunicationID END,
                       TARGET.CommunicationValue = CASE WHEN SOURCE.CommunicationValue = '' THEN NULL ELSE SOURCE.CommunicationValue END
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                HeadlineID,
                CompanyServiceID,
                isOffered,
                CommunicationID,
                CommunicationValue
            )
            VALUES (
                @HeadlineID,
                SOURCE.CompanyServiceID,
                SOURCE.isOffered,
                CASE WHEN SOURCE.CommunicationID = 0 THEN NULL ELSE SOURCE.CommunicationID END,
                CASE WHEN SOURCE.CommunicationValue = '' THEN NULL ELSE SOURCE.CommunicationValue END
            )
        WHEN NOT MATCHED BY SOURCE AND TARGET.HeadlineID = @HeadlineID
            THEN DELETE;
    END TRY
    BEGIN CATCH
        SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
        RETURN
    END CATCH


    -----------------------------------
    -- Get new value of Company Service

    CREATE TABLE #tmpCompanyServiceNewValue (
        HeadlineID         INT,
        CompanyServiceID   INT,
        CompanyServiceName NVARCHAR(1000),
        isOffered          VARCHAR(100),
        CommunicationID    INT,
        CommunicationTool  NVARCHAR(1000),
        CommunicationValue NVARCHAR(1000)
    )

    INSERT INTO #tmpCompanyServiceNewValue (
        HeadlineID,
        CompanyServiceID,
        CompanyServiceName,
        isOffered,
        CommunicationID,
        CommunicationTool,
        CommunicationValue
    )
    SELECT chc.HeadlineID                                       HeadlineID,
           chc.CompanyServiceID                                 CompanyServiceID,
           scs.SettingValue                                     CompanyServiceName,
           CASE WHEN chc.isOffered = 1 THEN 'Yes' ELSE 'No' END isOffered,
           chc.CommunicationID                                  CommunicationID,
           sc.SettingValue                                      CommunicationTool,
           chc.CommunicationValue                               CommunicationValue
    FROM bodb_CRM.dbo.crmCustomerHeadlineCompanyService chc WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmSetting scs WITH (NOLOCK) ON scs.SettingName = 'HeadlineCompanyService' AND chc.CompanyServiceID = scs.SettingID
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND chc.CommunicationID = sc.SettingID
    WHERE chc.HeadlineID = @HeadlineID
    OPTION (RECOMPILE)


    ------------
    -- Write log

    -- Prepare data
    -- + Variables
    DECLARE @CountRow                INT
    DECLARE @getHeadlineID           INT
    DECLARE @getCompanyServiceID     INT
    DECLARE @CompanyServiceOldValue  XML
    DECLARE @CompanyServiceNewValue  XML
    DECLARE @CompanyServiceNullValue XML = '<Acc_CRM_NewAccDetail_UpdHeadlineCompanyService>' +
                                           '<CompanyService>' +
                                           '</CompanyService>' +
                                           '</Acc_CRM_NewAccDetail_UpdHeadlineCompanyService>'
    -- + Temp table
    -- + --> Create temp table
    CREATE TABLE #tmpDataToLoop (
        HeadlineID       INT,
        CompanyServiceID INT,
        OldValue         NVARCHAR(MAX),
        NewValue         NVARCHAR(MAX),
        isProcessed      BIT DEFAULT(0)
    )
    -- + --> Gen data to temp table
    ;WITH
    CTE_OldValue AS (
        SELECT HeadlineID,
               CompanyServiceID,
               STRING_AGG(CAST(ISNULL('[Service] '            + dbo.f_EncodeXMLValue(CompanyServiceName) + '<br/>' +
                                      '[Offer] '              + dbo.f_EncodeXMLValue(isOffered)          + '<br/>' +
                                      '[Communication Tool] ' + ISNULL(dbo.f_EncodeXMLValue(CommunicationTool + ': ' + CommunicationValue), ''), '') AS NVARCHAR(MAX)), '<br/><br/>') OldValue
        FROM #tmpCompanyServiceOldValue
        GROUP BY HeadlineID,
                 CompanyServiceID
    ),
    CTE_NewValue AS (
        SELECT HeadlineID,
               CompanyServiceID,
               STRING_AGG(CAST(ISNULL('[Service] '            + dbo.f_EncodeXMLValue(CompanyServiceName) + '<br/>' +
                                      '[Offer] '              + dbo.f_EncodeXMLValue(isOffered)          + '<br/>' +
                                      '[Communication Tool] ' + ISNULL(dbo.f_EncodeXMLValue(CommunicationTool + ': ' + CommunicationValue), ''), '') AS NVARCHAR(MAX)), '<br/><br/>') NewValue
        FROM #tmpCompanyServiceNewValue
        GROUP BY HeadlineID,
                 CompanyServiceID
    )
    INSERT INTO #tmpDataToLoop (
        HeadlineID,
        CompanyServiceID,
        OldValue,
        NewValue
    )
    SELECT ISNULL(old.HeadlineID, new.HeadlineID)             HeadlineID,
           ISNULL(old.CompanyServiceID, new.CompanyServiceID) CompanyServiceID,
           old.OldValue                                       OldValue,
           new.NewValue                                       NewValue
    FROM CTE_OldValue old
         FULL OUTER JOIN CTE_NewValue new ON old.HeadlineID = new.HeadlineID AND old.CompanyServiceID = new.CompanyServiceID

    -- Process data
    WHILE (1=1)
    BEGIN
        -- + Check to break the loop
        SELECT @CountRow = COUNT(1) FROM #tmpDataToLoop WHERE isProcessed = 0
        IF (@CountRow = 0) BREAK

        -- + Get RowID|HeadlineID
        SELECT TOP(1) @getHeadlineID       = HeadlineID,
                      @getCompanyServiceID = CompanyServiceID
        FROM #tmpDataToLoop
        WHERE isProcessed = 0
        ORDER BY HeadlineID, CompanyServiceID

        -- + Get value to @CompanyServiceOldValue
        SELECT @CompanyServiceOldValue = '<Acc_CRM_NewAccDetail_UpdHeadlineCompanyService>' +
                                         '<CompanyService>' +
                                         ISNULL(OldValue, '') +
                                         '</CompanyService>' +
                                         '</Acc_CRM_NewAccDetail_UpdHeadlineCompanyService>'
        FROM #tmpDataToLoop
        WHERE HeadlineID = @getHeadlineID AND CompanyServiceID = @getCompanyServiceID

        IF(@CompanyServiceOldValue IS NULL)
        BEGIN
            SET @CompanyServiceOldValue = @CompanyServiceNullValue
        END

        -- + Get value to @CompanyServiceNewValue
        SELECT @CompanyServiceNewValue = '<Acc_CRM_NewAccDetail_UpdHeadlineCompanyService>' +
                                         '<CompanyService>' +
                                         ISNULL(NewValue, '') +
                                         '</CompanyService>' +
                                         '</Acc_CRM_NewAccDetail_UpdHeadlineCompanyService>'
        FROM #tmpDataToLoop
        WHERE HeadlineID = @getHeadlineID AND CompanyServiceID = @getCompanyServiceID

        IF(@CompanyServiceNewValue IS NULL)
        BEGIN
            SET @CompanyServiceNewValue = @CompanyServiceNullValue
        END

        -- + Write log
        IF (ISNULL(CAST(@CompanyServiceOldValue AS NVARCHAR(MAX)), '') <> ISNULL(CAST(@CompanyServiceNewValue AS NVARCHAR(MAX)), ''))
        BEGIN
            EXEC bodb_CRM.dbo.WriteLog_UserLog_crmLogCustomer @CustID    = @getHeadlineID,
                                                              @UserID    = @UserID,
                                                              @ActionID  = 110,
                                                              @IP        = @IP,
                                                              @NewValues = @CompanyServiceNewValue,
                                                              @OldValues = @CompanyServiceOldValue
        END

        -- + Update to continue the loop
        UPDATE tmp
        SET tmp.isProcessed = 1
        FROM #tmpDataToLoop tmp
        WHERE tmp.isProcessed = 0
              AND tmp.HeadlineID = @getHeadlineID
              AND tmp.CompanyServiceID = @getCompanyServiceID
    END


    ------------------
    -- Drop temp table

    DROP TABLE #tmpCompanyServices
    DROP TABLE #tmpCompanyServiceOldValue
    DROP TABLE #tmpCompanyServiceNewValue
    DROP TABLE #tmpDataToLoop

END
GO