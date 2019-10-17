# Parent issues controller.
# This controller provide sssignee evm view.
#
# 1. selectable list for parent issue view
# 2. calculate EVM each selected assignees
# 
class EvmparentissuesController < BaseevmController
  # index for parent issue EVM view.
  # 
  # 1. set options of view request
  # 2. get selectable list
  # 3. calculate EVM
  #
  def index
    # View options
    @cfg_param[:basis_date] = params[:basis_date]
    @cfg_param[:selected_parent_issue_id] = params[:selected_parent_issue_id]
    @cfg_param[:no_use_baseline] = "true"
    @cfg_param[:forecast] = "false"
    @cfg_param[:display_performance] = "false"
    @cfg_param[:display_incomplete] = "false"
    #selectable parent issue
    @selectable_parent_issue = selectable_parent_issues_list
    # calculate EVM (parent issue)
    @parent_issue_evm = {}
    @parent_issue_evm_chart = {}
    unless @cfg_param[:selected_parent_issue_id].nil?
      @cfg_param[:selected_parent_issue_id].each do |issue_id|
        # issues of parent issue
        parent_issue = parent_issues issue_id
        # spent time of parent issue
        parent_issue_actual_cost = parent_issue_costs issue_id
        # create array of EVM
        @parent_issue_evm[issue_id] = CalculateEvm.new nil,
                                                       parent_issue,
                                                       parent_issue_actual_cost,
                                                       @cfg_param
        # create chart data
        @parent_issue_evm_chart[issue_id] = chart_data @parent_issue_evm[issue_id]
      end
    end
  end
end
