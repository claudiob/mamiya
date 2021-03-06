require 'mamiya/logger'

module Mamiya
  class Agent
    module Tasks
      class Abstract
        def initialize(task_queue, task, agent: nil, logger: Mamiya::Logger.new, raise_error: false)
          @agent = agent
          @task_queue = task_queue
          @task = task.merge('task' => self.class.identifier)
          @error = nil
          @raise_error = raise_error
          @logger = logger["#{self.class.identifier}:#{self.task_id}"]
        end

        def self.identifier
          self.name.split(/::/).last.gsub(/(.)([A-Z])/, '\1_\2').downcase
        end

        attr_reader :task, :error, :logger, :agent, :task_queue

        def raise_error?
          !!@raise_error
        end

        def task_id
          task['id'] || "0x#{self.__id__.to_s(16)}"
        end

        def execute
          @logger.info "Task started: #{task.inspect}"
          before
          run
        rescue Exception => error
          @error = error
          raise if raise_error?
          errored
          @logger.error "Encountered error: #{error.inspect}\n\t#{error.backtrace.join("\n\t")}"
        ensure
          enqueue_chained unless error
          after
          @logger.info "Task finished"
        end

        def before
        end

        def run
        end

        def after
        end

        def errored
        end

        private

        def enqueue_chained
          return if !task['_chain'] || task['_chain'].empty?

          next_task = task.dup
          next_task.delete('task')

          next_task_name, *next_task['_chain'] = task['_chain']
          next_task.delete('_chain') if next_task['_chain'].empty?

          task_queue.enqueue(next_task_name.to_sym, next_task)
        end

        def config
          @config ||= agent ? agent.config : nil
        end
      end
    end
  end
end
