module Garrison
  module Checks
    class CheckDrift < Check

      def settings
        self.source ||= 'aws-cloudformation'
        self.severity ||= 'high'
        self.family ||= 'infrastructure'
        self.type ||= 'compliance'
        self.options[:regions] ||= 'all'
      end

      def key_values
        [
          { key: 'datacenter', value: 'aws' },
          { key: 'aws-service', value: 'cloudformation' },
          { key: 'aws-account', value: AwsHelper.whoami }
        ]
      end

      def perform
        options[:regions] = AwsHelper.all_regions if options[:regions] == 'all'
        options[:regions].each do |region|
          Logging.info "Checking region #{region}"
          cf = cloudformation(region)
          AwsHelper.list_stacks(cf).each do |stack|
            Logging.info "Checking stack #{stack.stack_id}"
            drift_status = AwsHelper.detect_drift(cf, stack)
            next if drift_status.detection_status == 'DETECTION_FAILED'

            if drift_status.stack_drift_status == 'DRIFTED'
              alert(
                name: 'CloudFormation Drift Violation',
                target: drift_status.stack_id,
                detail: "drift: #{drift_status.drifted_stack_resource_count}",
                finding: drift_status.to_h.to_json,
                finding_id: "aws-cloudformation-#{drift_status.stack_id}-drift",
                urls: [
                  {
                    name: 'AWS Dashboard',
                    url: "https://console.aws.amazon.com/cloudformation/home?region=#{region}#/stacks/#{URI.escape(drift_status.stack_id, ":/")}/drifts"
                  }
                ],
                key_values: [
                  {
                    key: 'aws-region',
                    value: region
                  }
                ]
              )
            end
          end
        end
      end

      private

      def cloudformation(region)
        if ENV['AWS_ASSUME_ROLE_CREDENTIALS_ARN']
          role_credentials = Aws::AssumeRoleCredentials.new(
            client: Aws::STS::Client.new(region: region),
            role_arn: ENV['AWS_ASSUME_ROLE_CREDENTIALS_ARN'],
            role_session_name: 'garrison-agent-cloudformation'
          )
          Aws::CloudFormation::Client.new(credentials: role_credentials, region: region)
        else
          Aws::CloudFormation::Client.new(region: region)
        end
      end
    end
  end
end
