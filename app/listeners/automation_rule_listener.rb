class AutomationRuleListener < BaseListener
  def conversation_updated(event)
    process_conversation_event(event, 'conversation_updated')
  end

  def conversation_created(event)
    process_conversation_event(event, 'conversation_created')
  end

  def conversation_opened(event)
    process_conversation_event(event, 'conversation_opened')
  end

  def conversation_resolved(event)
    process_conversation_event(event, 'conversation_resolved')
  end

  def message_created(event)
    message = event.data[:message]

    return if ignore_message_created_event?(event)

    account = message.try(:account)
    changed_attributes = event.data[:changed_attributes]

    return unless rule_present?('message_created', account)

    rules = current_account_rules('message_created', account)

    rules.each do |rule|
      # 检查规则是否最近被执行过（防止重复触发）
      if rule_recently_executed?(rule, message.conversation)
        Rails.logger.debug(
          "[AutomationRule] Rule #{rule.id} (#{rule.event_name}) recently executed, skipping for conversation #{message.conversation.id}"
        )
        next
      end
      
      conditions_match = ::AutomationRules::ConditionsFilterService.new(rule, message.conversation,
                                                                        { message: message, changed_attributes: changed_attributes }).perform
      if conditions_match.present?
        Rails.logger.info(
          "[AutomationRule] Executing rule #{rule.id} (#{rule.event_name}) for conversation #{message.conversation.id}"
        )
        ::AutomationRules::ActionService.new(rule, account, message.conversation).perform
      end
    end
  end

  private

  def process_conversation_event(event, event_name)
    return if performed_by_automation?(event)

    auto_reply_skip_events = %w[conversation_created conversation_opened]
    return if auto_reply_skip_events.include?(event_name) && ignore_auto_reply_event?(event)

    conversation = event.data[:conversation]
    account = conversation.account
    changed_attributes = event.data[:changed_attributes]

    return unless rule_present?(event_name, account)

    rules = current_account_rules(event_name, account)

    rules.each do |rule|
      # 检查规则是否最近被执行过（防止重复触发）
      if rule_recently_executed?(rule, conversation)
        Rails.logger.debug(
          "[AutomationRule] Rule #{rule.id} (#{rule.event_name}) recently executed, skipping for conversation #{conversation.id}"
        )
        next
      end
      
      conditions_match = ::AutomationRules::ConditionsFilterService.new(rule, conversation, { changed_attributes: changed_attributes }).perform
      if conditions_match.present?
        Rails.logger.info(
          "[AutomationRule] Executing rule #{rule.id} (#{rule.event_name}) for conversation #{conversation.id}"
        )
        AutomationRules::ActionService.new(rule, account, conversation).perform
      end
    end
  end

  def rule_present?(event_name, account)
    return if account.blank?

    current_account_rules(event_name, account).any?
  end

  def current_account_rules(event_name, account)
    AutomationRule.where(
      event_name: event_name,
      account_id: account.id,
      active: true
    )
  end

  def performed_by_automation?(event)
    event.data[:performed_by].present? && event.data[:performed_by].instance_of?(AutomationRule)
  end

  def ignore_auto_reply_event?(event)
    conversation = event.data[:conversation]
    conversation.additional_attributes['auto_reply'].present?
  end

  def ignore_message_created_event?(event)
    message = event.data[:message]
    performed_by_automation?(event) || message.activity? || message.auto_reply_email?
  end

  # 检查规则是否在时间窗口内已被执行过
  # 防止同一个规则在短时间内被多次触发
  def rule_recently_executed?(rule, conversation, time_window: 60)
    # 检查对话中是否有该规则在时间窗口内发送的消息
    # 排除已删除的消息（content_attributes->>'deleted' != 'true'）
    # 只检查未删除的消息，因为已删除的消息不应该阻止规则重新执行
    conversation.messages
                .outgoing
                .where('created_at > ?', time_window.seconds.ago)
                .where("content_attributes->>'automation_rule_id' = ?", rule.id.to_s)
                .where("(content_attributes->>'deleted' IS NULL OR content_attributes->>'deleted' != 'true')")
                .exists?
  end
end
