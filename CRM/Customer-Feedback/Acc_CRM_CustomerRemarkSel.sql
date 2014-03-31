
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CustomerRemarkSel    Script Date: 3/26/2014 6:06:05 PM ******/
CREATE PROCEDURE Acc_CRM_CustomerRemarkSel
	@CustID INT
AS

SELECT * FROM crmCustomerRemark(NOLOCK) WHERE CustID = @CustID


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerRemarkSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerRemarkSel] TO [vnteam]
GO 
