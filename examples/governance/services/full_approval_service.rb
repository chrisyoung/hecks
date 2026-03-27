# FullApprovalService
#
# Orchestrates model approval: approves the compliance review, then
# approves the model itself.
#
#   FullApprovalService.approve(model_id: id, review_id: id, notes: "OK")
#
class FullApprovalService
  def self.approve(model_id:, review_id:, notes:)
    ComplianceReview.approve(review_id: review_id, notes: notes)
    AiModel.approve(model_id: model_id)
    AiModel.find(model_id)
  end
end
