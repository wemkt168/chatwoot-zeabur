require 'set'

class AutomationRules::DuplicateMessagePreventionService
  # 检查是否应该跳过发送消息（防止重复）
  # @param conversation [Conversation] 对话对象
  # @param message_content [String] 要发送的消息内容
  # @param automation_rule_id [Integer] 自动化规则 ID
  # @param time_window [Integer] 时间窗口（秒），默认 5 分钟
  # @return [Boolean] true 如果应该跳过（有重复），false 如果应该发送
  def self.should_skip_message?(conversation:, message_content:, automation_rule_id:, time_window: 300)
    return false if message_content.blank?

    # 1. 检查时间窗口内是否有相同内容的消息（由自动化规则发送）
    # 排除已删除的消息（content_attributes->>'deleted' != 'true'）
    recent_duplicate = conversation.messages
                                    .outgoing
                                    .where('created_at > ?', time_window.seconds.ago)
                                    .where("content_attributes->>'automation_rule_id' = ?", automation_rule_id.to_s)
                                    .where("(content_attributes->>'deleted' IS NULL OR content_attributes->>'deleted' != 'true')")
                                    .where('content = ?', message_content.strip)
                                    .exists?

    return true if recent_duplicate

    # 2. 检查是否有非常相似的消息（内容相似度 > 80%）
    similar_message = find_similar_message(conversation, message_content, automation_rule_id, time_window)
    return true if similar_message

    false
  end

  # 检查对话中是否有相似的消息
  # @param conversation [Conversation] 对话对象
  # @param message_content [String] 要发送的消息内容
  # @param automation_rule_id [Integer] 自动化规则 ID
  # @param time_window [Integer] 时间窗口（秒）
  # @return [Boolean] true 如果找到相似消息
  def self.find_similar_message(conversation, message_content, automation_rule_id, time_window)
    normalized_content = normalize_message(message_content)
    
    conversation.messages
                .outgoing
                .where('created_at > ?', time_window.seconds.ago)
                .where("content_attributes->>'automation_rule_id' = ?", automation_rule_id.to_s)
                .where("(content_attributes->>'deleted' IS NULL OR content_attributes->>'deleted' != 'true')")
                .find_each do |message|
      # 双重检查：跳过已删除的消息
      next if message.content_attributes&.dig('deleted') == true
      
      normalized_existing = normalize_message(message.content)
      similarity = calculate_similarity(normalized_content, normalized_existing)
      
      # 如果相似度超过 80%，认为是重复消息
      return true if similarity > 0.8
    end

    false
  end

  # 标准化消息内容（用于比较）
  # 移除多余空格、换行符、标点符号等
  def self.normalize_message(content)
    return '' if content.blank?

    content.strip
           .downcase
           .gsub(/\s+/, ' ') # 多个空格替换为单个空格
           .gsub(/[[:punct:]]/, '') # 移除标点符号
  end

  # 计算两个字符串的相似度（使用简单的 Jaccard 相似度）
  # @param str1 [String] 第一个字符串
  # @param str2 [String] 第二个字符串
  # @return [Float] 相似度（0.0 到 1.0）
  def self.calculate_similarity(str1, str2)
    return 1.0 if str1 == str2
    return 0.0 if str1.blank? || str2.blank?

    # 使用简单的字符集相似度
    set1 = str1.chars.to_set
    set2 = str2.chars.to_set

    intersection = (set1 & set2).size
    union = (set1 | set2).size

    return 0.0 if union.zero?

    intersection.to_f / union
  end
end

