
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_RedemptionSel    Script Date: 3/26/2014 6:06:08 PM ******/
CREATE PROCEDURE Acc_CRM_RedemptionSel
	@ID INT
AS

SELECT r.ID,r.Subject,r.ClaimTime,r.StatusID,r.Remark,r.CustID FROM crmRedemption(NOLOCK) r
WHERE r.ID = @ID


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_RedemptionSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_RedemptionSel] TO [vnteam]
GO 
