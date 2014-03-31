
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_MainInformationSpecialRemarkSel    Script Date: 3/26/2014 6:06:08 PM ******/
CREATE PROC Acc_CRM_MainInformationSpecialRemarkSel
	@CustID INT
AS

/*
Created: Dom
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	
Param's Explanation:	
*/
SELECT TOP 5 Remark FROM crmCustomerRemark(NOLOCK) 
WHERE CustID = @CustID AND IsSpecial = 1


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationSpecialRemarkSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_MainInformationSpecialRemarkSel] TO [vnteam]
GO 
