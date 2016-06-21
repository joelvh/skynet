class V1::RecordsController < V1::ApplicationController
  def records_show
    check_permissions(__method__)
    expires_in 30.minutes, public: true
    @status, @result = @api.records.show(params)
    json_response(@status, @result)
  end
end