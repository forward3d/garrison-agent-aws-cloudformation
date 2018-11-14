module Garrison
  class AwsHelper

    def self.whoami
      @whoami ||= ENV['AWS_ACCOUNT_ID'] || Aws::STS::Client.new(region: 'us-east-1').get_caller_identity.account
    end

    def self.all_regions
      Aws.partition('aws').regions.map(&:name)
    end

    def self.list_stacks(cloudformation)
      Enumerator.new do |yielder|
        token = ''

        loop do
          Logging.debug "AWS SDK - Listings Stacks (token=#{token})"
          params = {}
          params[:next_token] = token if token != ''
          params[:stack_status_filter] = %w(CREATE_COMPLETE ROLLBACK_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE)
          results = cloudformation.list_stacks(params)
          results.stack_summaries.map { |item| yielder << item }

          if results.next_token
            next_token = results.next_token
          else
            raise StopIteration
          end
        end
      end.lazy
    end

    def self.detect_drift(cloudformation, stack)
      stack_drift_detection = cloudformation.detect_stack_drift(stack_name: stack.stack_id)
      Logging.debug "AWS SDK - Checking Drift (stack=#{stack.stack_id} stack_drift_detection_id=#{stack_drift_detection.stack_drift_detection_id})"

      drift_status = nil
      status = 'DETECTION_IN_PROGRESS'

      while status == 'DETECTION_IN_PROGRESS' do
        drift_status = cloudformation.describe_stack_drift_detection_status(stack_drift_detection_id: stack_drift_detection.stack_drift_detection_id)
        Logging.debug "AWS SDK - Drift Detection Status (stack=#{stack.stack_id} detection_status=#{drift_status.detection_status})"
        status = drift_status.detection_status
        sleep(2)
      end

      drift_status
    end

  end
end
