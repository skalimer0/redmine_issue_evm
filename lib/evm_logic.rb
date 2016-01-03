module EvmLogic
  class IssueEvm
    # Constractor
    #
    # @param [evmbaseline] baselines selected baseline.
    # @param [issue] issues
    # @param [hash] costs spent time.
    # @param [date] basis_date basis date.
    # @param [bool] forecast forecast of option.
    # @param [String] etc_method etc method of option.
    # @param [bool] no_use_baseline no use baseline of option.
    # @param [Numeric] working_hours_of_day hours per day.
    def initialize(baselines, issues, costs, basis_date, forecast, etc_method, no_use_baseline, working_hours_of_day)
      # basis hours per day
      @basis_hours_per_day = working_hours_of_day
      # Basis date
      @basis_date = basis_date
      # option
      @forecast = forecast
      @etc_method = etc_method
      @issue_max_date = issues.maximum(:due_date)
      # PV-ACTUAL for chart
      @pv_actual = calculate_planed_value issues
      # PV-BASELINE for chart
      @pv_baseline = calculate_planed_value baselines
      # PV
      @pv = no_use_baseline ? @pv_actual : @pv_baseline
      # EV
      @ev = calculate_earned_value issues
      # AC
      @ac = calculate_actual_cost costs
      # Project finished?
      if (@pv_actual[@pv_actual.keys.max] == @ev[@ev.keys.max]) || (@pv_baseline[@pv_baseline.keys.max] == @ev[@ev.keys.max])
        delete_basis_date = [@pv.keys.max, @ev.keys.max, @ac.keys.max].max
        @pv.delete_if { |date, _value| date > delete_basis_date }
        @ev.delete_if { |date, _value| date > delete_basis_date }
        @ac.delete_if { |date, _value| date > delete_basis_date }
        @pv_actual.delete_if { |date, _value| date > delete_basis_date }
        @pv_baseline.delete_if { |date, _value| date > delete_basis_date }
        # when project is finished, forecast is disable.
        @forecast = false
      end
      # To calculate the EVM value
      @pv_value = @pv[basis_date] || @pv[@pv.keys.max]
      @ev_value = @ev[basis_date] || @ev[@ev.keys.max]
      @ac_value = @ac[basis_date] || @ac[@ac.keys.max]
    end

    # Basis date
    attr_reader :basis_date

    # Badget at completion.
    # Total hours of issues.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] BAC
    def bac(hours = 1)
      bac = @pv[@pv.keys.max] / hours
      bac.round(1)
    end

    # CompleteEV
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] EV / BAC
    def complete_ev(hours = 1)
      complete_ev = bac(hours) == 0.0 ? 0.0 : (today_ev(hours) / bac(hours)) * 100.0
      complete_ev.round(1)
    end

    # Planed value
    # The work scheduled to be completed by a specified date.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] PV on basis date
    def today_pv(hours = 1)
      pv = @pv_value / hours
      pv.round(1)
    end

    # Earned value
    # The work actually completed by the specified date;.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] EV on basis date
    def today_ev(hours = 1)
      ev = @ev_value / hours
      ev.round(1)
    end

    # Actual cost
    # The costs actually incurred for the work completed by the specified date.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] AC on basis date
    def today_ac(hours = 1)
      ac = @ac_value / hours
      ac.round(1)
    end

    # Scedule variance
    # How much ahead or behind the schedule a project is running.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] EV - PV on basis date
    def today_sv(hours = 1)
      sv = today_ev(hours) - today_pv(hours)
      sv.round(1)
    end

    # Cost variance
    # Cost Variance (CV) is a very important factor to measure project performance.
    # CV indicates how much over - or under-budget the project is.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] EV - AC on basis date
    def today_cv(hours = 1)
      cv = today_ev(hours) - today_ac(hours)
      cv.round(1)
    end

    # Schedule Performance Indicator
    # Schedule Performance Indicator (SPI) is an index showing
    # the efficiency of the time utilized on the project.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] EV / PV on basis date
    def today_spi(hours = 1)
      spi = today_ev(hours) == 0.0 || today_pv(hours) == 0.0 ? 0.0 : today_ev(hours) / today_pv(hours)
      spi.round(2)
    end

    # Cost Performance Indicator
    # ost Performance Indicator (CPI) is an index showing
    # the efficiency of the utilization of the resources on the project.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] EV / AC on basis date
    def today_cpi(hours = 1)
      cpi = today_ev(hours) == 0.0 || today_ac(hours) == 0.0 ? 0.0 : today_ev(hours) / today_ac(hours)
      cpi.round(2)
    end

    # CR
    def today_cr(hours = 1)
      cr = today_spi(hours) * today_cpi(hours)
      cr.round(2)
    end

    # Estimate to Complete
    # Estimate to Complete (ETC) is the estimated cost required
    # to complete the remainder of the project.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] (BAC - EV) / CPI
    def etc(hours = 1)
      if today_cpi(hours) == 0.0 || today_cr(hours) == 0.0
        etc = 0.0
      else
        case @etc_method
        when 'method1' then
          div_value = 1.0
        when 'method2' then
          div_value = today_cpi(hours)
        when 'method3' then
          div_value = today_cr(hours)
        else
          div_value = today_cpi(hours)
        end
        etc = (bac(hours) - today_ev(hours)) / div_value
      end
      etc.round(1)
    end

    # Estimate at Completion
    # Estimate at Completion (EAC) is the estimated cost of the project
    # at the end of the project.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] BAC - EAC
    def eac(hours = 1)
      eac = today_ac(hours) + etc(hours)
      eac.round(1)
    end

    # Variance at Completion
    # Variance at completion (VAC) is the variance
    # on the total budget at the end of the project.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] BAC - EAC
    def vac(hours = 1)
      vac = bac(hours) - eac(hours)
      vac.round(1)
    end

    # Delay
    def delay
      (forecast_finish_date(@basis_hours_per_day) - @pv.keys.max).to_i
    end

    # To Complete Cost Performance Indicator
    # To Complete Cost Performance Indicator (TCPI) is an index showing
    # the efficiency at which the resources on the project should be utilized
    # for the remainder of the project.
    #
    # @param [Numeric] hours hours per day
    # @return [Numeric] (BAC - EV) / (BAC - AC)
    def tcpi(hours = 1)
      tcpi = bac(hours) == 0.0 ? 0.0 : (bac(hours) - today_ev(hours)) / (bac(hours) - today_ac(hours))
      tcpi.round(1)
    end

    # Create data for display chart.
    #
    # @return [hash] chart data
    def chart_data
      chart_data = {}
      if @issue_max_date < @basis_date && complete_ev < 100.0
        @ev[@basis_date] = @ev[@ev.keys.max]
        @ac[@basis_date] = @ac[@ac.keys.max]
      end
      chart_data['planned_value'] = convert_to_chart(@pv_actual)
      chart_data['actual_cost'] = convert_to_chart(@ac)
      chart_data['earned_value'] = convert_to_chart(@ev)
      chart_data['baseline_value'] = convert_to_chart(@pv_baseline)
      if @forecast
        bac_top_line = { chart_minimum_date => bac, chart_maximum_date => bac }
        chart_data['bac_top_line'] = convert_to_chart(bac_top_line)
        eac_top_line = { chart_minimum_date => eac, chart_maximum_date => eac }
        chart_data['eac_top_line'] = convert_to_chart(eac_top_line)
        actual_cost_forecast = { @basis_date => today_ac, forecast_finish_date(@basis_hours_per_day) => eac }
        chart_data['actual_cost_forecast'] = convert_to_chart(actual_cost_forecast)
        earned_value_forecast = { @basis_date => today_ev, forecast_finish_date(@basis_hours_per_day) => bac }
        chart_data['earned_value_forecast'] = convert_to_chart(earned_value_forecast)
      end
      chart_data
    end

    # Create data for display performance chart.
    def performance_chart_data
      chart_data = {}
      new_ev = complement_evm_value @ev
      new_ac = complement_evm_value @ac
      new_pv = complement_evm_value @pv
      performance_min_date = [new_ev.keys.min, new_ac.keys.min, new_pv.keys.min].max
      performance_max_date = [new_ev.keys.max, new_ac.keys.max, new_pv.keys.max].min
      spi = {}
      cpi = {}
      cr = {}
      (performance_min_date..performance_max_date).each do |date|
        spi[date] = (new_ev[date] / new_pv[date]).round(2)
        cpi[date] = (new_ev[date] / new_ac[date]).round(2)
        cr[date] = (spi[date] * cpi[date]).round(2)
      end
      chart_data['spi'] = convert_to_chart(spi)
      chart_data['cpi'] = convert_to_chart(cpi)
      chart_data['cr'] = convert_to_chart(cr)
      chart_data
    end

    # Create data for csv export.
    #
    # @return [hash] csv data
    def to_csv
      CSV.generate do |csv|
        # date range
        csv_min_date = [@ev.keys.min, @ac.keys.min, @pv.keys.min].min
        csv_max_date = [@ev.keys.max, @ac.keys.max, @pv.keys.max].max
        evm_date_range = (csv_min_date..csv_max_date).to_a
        # title
        csv << ["DATE",evm_date_range].flatten!
        # set evm values each date
        pv_csv_hash = {}
        ev_csv_hash = {}
        ac_csv_hash = {}
        evm_date_range.each do |csv_date|
          pv_csv_hash[csv_date] = @pv[csv_date].nil? ? nil : @pv[csv_date].round(2)
          ev_csv_hash[csv_date] = @ev[csv_date].nil? ? nil : @ev[csv_date].round(2)
          ac_csv_hash[csv_date] = @ac[csv_date].nil? ? nil : @ac[csv_date].round(2)
        end
        # evm values
        csv << ["PV",pv_csv_hash.values.to_a].flatten!
        csv << ["EV",ev_csv_hash.values.to_a].flatten!
        csv << ["AC",ac_csv_hash.values.to_a].flatten!
      end
    end

    private

    # Calculate PV.
    #
    # @param [issue] issues target issues of EVM
    # @return [hash] EVM hash. Key:Date, Value:PV of each days
    def calculate_planed_value(issues)
      temp_pv = {}
      unless issues.nil?
        issues.each do |issue|
          hours_per_day = issue_hours_per_day(issue.estimated_hours.to_f, issue.start_date, issue.due_date)
          (issue.start_date..issue.due_date).each do |date|
            temp_pv[date].nil? ? temp_pv[date] = hours_per_day : temp_pv[date] += hours_per_day
          end
        end
      end
      sort_and_sum_evm_hash(temp_pv)
    end

    # Calculate EV.
    # Only closed issues.
    #
    # @param [issue] issues target issues of EVM
    # @return [hash] EVM hash. Key:Date, Value:EV of each days
    def calculate_earned_value(issues)
      temp_ev = {}
      unless issues.nil?
        issues.each do |issue|
          if issue.closed?
            close_date = issue.closed_on.to_time.to_date
            temp_ev[close_date].nil? ? temp_ev[close_date] = issue.estimated_hours.to_f : temp_ev[close_date] += issue.estimated_hours.to_f
          elsif issue.done_ratio > 0
            estimated_hours = issue.estimated_hours.to_f * issue.done_ratio / 100.0
            start_date = [issue.start_date, @basis_date].min
            end_date = [issue.due_date, @basis_date].max
            hours_per_day = issue_hours_per_day(estimated_hours, start_date, end_date)
            (start_date..end_date).each do |date|
              temp_ev[date].nil? ? temp_ev[date] = hours_per_day : temp_ev[date] += hours_per_day
            end
          end
        end
      end
      calculate_earned_value = sort_and_sum_evm_hash(temp_ev)
      calculate_earned_value.delete_if { |date, _value| date > @basis_date }
    end

    # Calculate AC.
    # Spent time of target issues.
    #
    # @param [issue] costs target issues of EVM
    # @return [hash] EVM hash. Key:Date, Value:AC of each days
    def calculate_actual_cost(costs)
      temp_ac = Hash[costs]
      calculate_actual_cost = sort_and_sum_evm_hash(temp_ac)
      calculate_actual_cost.delete_if { |date, _value| date > @basis_date }
    end

    # Convert to chart. xAxis of Chart is time.
    #
    # @param [hash] hash_with_data target issues of EVM
    # @return [array] EVM hash. Key:time, Value:EVM value
    def convert_to_chart(hash_with_data)
      hash_converted = Hash[hash_with_data.map { |k, v| [k.to_time.to_i * 1000, v] }]
      hash_converted.to_a
    end

    # Sort key value. key value is DATE.
    # Assending date.
    #
    # @param [hash] evm_hash target issues of EVM
    # @return [hash] Sorted EVM hash. Key:time, Value:EVM value
    def sort_and_sum_evm_hash(evm_hash)
      temp_hash = {}
      sum_value = 0.0
      if evm_hash.blank?
        evm_hash[@basis_date] = 0.0
      elsif @basis_date <= @issue_max_date
        evm_hash[@basis_date] = 0.0 if evm_hash[@basis_date].nil?
      end
      evm_hash.sort_by { |key, _val| key }.each do |date, value|
        sum_value += value
        temp_hash[date] = sum_value
      end
      temp_hash
    end

    # Estimated time per day.
    #
    # @param [Numeric] estimated_hours estimated hours
    # @param [date] start_date start date of issue
    # @param [date] end_date end date of issue
    # @return [numeric] estimated hours per day
    def issue_hours_per_day(estimated_hours, start_date, end_date)
      (estimated_hours || 0.0) / (end_date - start_date + 1)
    end

    # Minimam date of chart.
    #
    # @return [date] Most minimum date of PV,EV,AC
    def chart_minimum_date
      [@pv.keys.min, @ev.keys.min, @ac.keys.min].min
    end

    # Maximum date of chart.
    #
    # @return [date] Most maximum date of PV,EV,AC,End date of forecast
    def chart_maximum_date
      [@pv.keys.max, @ev.keys.max, @ac.keys.max, forecast_finish_date(@basis_hours_per_day)].max
    end

    # End of project day.(forecast)
    #
    # @param [date] basis_hours hours of per day is plugin setting
    # @return [date] End of project date
    def forecast_finish_date(basis_hours)
      if complete_ev(basis_hours) == 100.0
        @ev.keys.max
      elsif today_spi(basis_hours) == 0.0
        @pv.keys.max
      else
        if @issue_max_date < @basis_date
          rest_days = (@pv[@pv.keys.max] - @ev[@ev.keys.max]) / today_spi(basis_hours) / basis_hours
          @basis_date + rest_days
        else
          rest_days = @pv.reject { |key, _value| key <= @basis_date }.size
          @pv.keys.max - (rest_days - (rest_days / today_spi(basis_hours)))
        end
      end
    end

    # EVM value of Each date.
    #
    # @param [hash] evm_hash EVM hash
    # @return [hash] EVM value of All date
    def complement_evm_value(evm_hash)
      before_date = evm_hash.keys.min
      before_value = evm_hash[evm_hash.keys.min]
      temp = {}
      evm_hash.each do |date, value|
        dif_days = (date - before_date - 1).to_i
        dif_value = (value - before_value) / dif_days
        if dif_days > 0
          sum_value = 0.0
          for add_days in 1..dif_days do
            tmpdate = before_date + add_days
            sum_value += dif_value
            temp[tmpdate] = before_value + sum_value
          end
        end
        before_date = date
        before_value = value
        temp[date] = value
      end
      temp
    end
  end
end
