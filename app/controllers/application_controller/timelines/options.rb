module ApplicationController::Timelines
  SELECT_EVENT_TYPE = [[N_('Management Events'), 'timeline'], [N_('Policy Events'), 'policy_timeline']].freeze

  DateOptions = Struct.new(
    :daily,
    :days,
    :end,
    :hourly,
    :start,
    :typ
  ) do
    def update_from_params(params)
      self.typ = params[:tl_typ] if params[:tl_typ]
      self.days = params[:tl_days] if params[:tl_days]
      self.hourly = params[:miq_date_1] || params[:miq_date] if (params[:miq_date_1] || params[:miq_date]) && typ == 'Hourly'
      self.daily = params[:miq_date_1] || params[:miq_date] if (params[:miq_date_1] || params[:miq_date]) && typ == 'Daily'
    end

    def update_start_end(sdate, edate)
      if !sdate.nil? && !edate.nil?
        self.start = [sdate.year.to_s, (sdate.month - 1).to_s, sdate.day.to_s].join(", ")
        self.end = [edate.year.to_s, (edate.month - 1).to_s, edate.day.to_s].join(", ")
        self.hourly ||= [edate.month, edate.day, edate.year].join("/")
        self.daily ||= [edate.month, edate.day, edate.year].join("/")
      else
        self.start = self.end = nil
      end
      self.days ||= "7"
    end
  end

  ManagementEventsOptions = Struct.new(
    :level,
    :categories,
  ) do
    def update_from_params(params)
      self.level = params[:tl_fl_typ] == "critical" ? :critical : :detail
      self.categories = {}
      if params[:tl_categories]
        params[:tl_categories].each do |category|
          categories[events[category]] = {:display_name => category}
          categories[events[category]][:event_groups] = level == :critical ?
            event_groups[events[category]][level] :
            event_groups[events[category]][level] + event_groups[events[category]][:critical]
        end
      end
    end

    def events
      @events ||= event_groups.each_with_object({}) do |egroup, hash|
        gname, list = egroup
        hash[list[:name].to_s] = gname
      end
    end

    def event_set
      event_set = []
      categories.each do |category|
        event_set.push(category.last[:event_groups])
      end
      event_set
    end

    def drop_cache
      @events = @event_groups = nil
    end

    def event_groups
      @event_groups ||= EmsEvent.event_groups
    end
  end

  PolicyEventsOptions = Struct.new(
    :categories,
    :result
  ) do
    def update_from_params(params)
      self.result = params[:tl_result] || "success"
      self.categories = {}
      if params[:tl_categories]
        params[:tl_categories].each do |category|
          categories[category] = {:display_name => category, :event_groups => events[category]}
        end
      end
    end

    def events
      @events ||= MiqEventDefinitionSet.all.each_with_object({}) do |event, hash|
        hash[event.description] = event.members.collect(&:name)
      end
    end

    def drop_cache
      @events = @fltr_cache = nil
    end

    def event_set
      categories.blank? ? [] : categories.collect { |_, e| e[:event_groups] }
    end

  end

  Options = Struct.new(
    :date,
    :model,
    :management,
    :policy,
    :tl_show,
  ) do
    def initialize(*args)
      super
      self.date       = DateOptions.new
      self.management = ManagementEventsOptions.new
      self.policy     = PolicyEventsOptions.new
    end

    def management_events?
      tl_show == 'timeline'
    end

    def policy_events?
      tl_show == 'policy_timeline'
    end

    def evt_type
      management_events? ? :event_streams : :policy_events
    end

    def event_set
      (policy_events? ? policy : management).event_set
    end

    def drop_cache
      [policy, management].each(&:drop_cache)
    end
  end
end
