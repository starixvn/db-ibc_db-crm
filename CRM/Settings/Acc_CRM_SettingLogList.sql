
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_SettingLogList    Script Date: 3/26/2014 6:06:09 PM ******/
CREATE PROCEDURE Acc_CRM_SettingLogList
AS
SELECT ActionID,SPName,ActionNameEN ActionName FROM crmLogAction(NOLOCK) WHERE ActionID BETWEEN 300 and 399


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_SettingLogList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingLogList] TO [vnteam]
GO 
