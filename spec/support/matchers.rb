# frozen_string_literal: true

require "rails/dom/testing"

def equal_to_dom(text)
  EqualToDom.new(text)
end

def match_css_pattern(pattern)
  CssPattern.new(pattern)
end

class EqualToDom
  include Rails::Dom::Testing::Assertions::DomAssertions

  def initialize(expectation)
    @expectation = normalize(expectation)
  end

  def matches?(text)
    @matcher = normalize(text)
    compare_doms(@expectation, @matcher, false)
  end

  def normalize(text)
    fragment(text)
  end

  def failure_message
    "Expected dom \n#{@matcher}\n to match \n#{@expectation}\n, but it wasn't"
  end

  def description
    "equal to dom #{@expectation[0..20]}"
  end
end

class CssPattern
  def initialize(pattern)
    @css_pattern = pattern
    @error_message = nil
    return if @css_pattern.is_a?(Hash)

    @css_pattern = Array(@css_pattern).map do |key|
      [key, 1]
    end
  end

  def error!(message)
    @error_message = message
    false
  end

  def matches?(text)
    text = text.clone.force_encoding("UTF-8") if "1.9.3".respond_to? :force_encoding

    @matcher = Nokogiri::HTML::DocumentFragment.parse(text)
    @css_pattern.each do |css, amount_or_pattern_or_string_or_proc|
      path = @matcher.css(css)
      case amount_or_pattern_or_string_or_proc
      when String, Regexp
        pattern_or_string = amount_or_pattern_or_string_or_proc
        html = path.inner_html
        unless html.match(pattern_or_string)
          return error!("#{css.inspect} did not match #{pattern_or_string.inspect}. It was \n:#{html.inspect}")
        end
      when Numeric
        expected_amount = amount_or_pattern_or_string_or_proc
        amount = path.size
        if amount != expected_amount
          return error!("did not find #{css.inspect} #{expected_amount.inspect} times. It was #{amount.inspect}")
        end
      when Proc
        unless amount_or_pattern_or_string_or_proc.call(path)
          return error!("#{css.inspect} did not validate (proc must not return a falsy value)")
        end
      else
        raise "Instance of String, Rexexp, Proc or Fixnum required"
      end
    end
  end

  def failure_message
    @error_message || "Expected to match dom pattern. But it wasn't."
  end

  def failure_message_when_negated
    "Expected to not match dom pattern. But it was."
  end

  def description
    "match dom pattern"
  end
end
