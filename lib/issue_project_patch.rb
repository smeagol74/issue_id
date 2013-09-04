require_dependency 'project'

module IssueProjectPatch

    def self.included(base)
        base.const_set(:ISSUE_KEY_MAX_LENGTH, 10)
        base.send(:include, InstanceMethods)
        base.class_eval do
            unloadable

            has_one :key, :class_name => 'ProjectIssueKey', :primary_key => :issue_key, :foreign_key => :project_key

            validates_length_of :issue_key, :in => 1..Project::ISSUE_KEY_MAX_LENGTH, :allow_blank => true
            validates_format_of :issue_key, :with => %r{^[A-Z][A-Z0-9]*$}, :allow_blank => true

            validate :validate_issue_key_duplicates

            after_save :migrate_issue_ids

            safe_attributes 'issue_key'

            def issue_key=(key)
                super if issue_key.blank? || new_record?
            end

        end
    end

    module InstanceMethods

        def copy_issue_key_to_subprojects
            if issue_key.present?
                children.each do |subproject|
                    if subproject.issue_key.blank?
                        subproject.issue_key = issue_key
                        if subproject.save
                            subproject.copy_issue_key_to_subprojects
                        end
                    end
                end
            end
        end

    private

        def validate_issue_key_duplicates
            if issue_key.present?
                project_key = ProjectIssueKey.find_by_project_key(issue_key)
                if project_key && project_key.projects.any?
                    settings = Setting.plugin_issue_id
                    if settings.is_a?(Hash) && settings[:issue_key_sharing]
                        if (!parent || issue_key != parent.issue_key) && (children & project_key.projects).size == 0
                            errors.add(:issue_key, :taken)
                        end
                    else
                        errors.add(:issue_key, :taken)
                    end
                end
            end
        end

        def migrate_issue_ids
            if issue_key.present?
                project_key = ProjectIssueKey.find_or_create_by_project_key(issue_key)
                Issue.all(:conditions => { :project_id => project_key.projects.collect(&:id),
                                           :project_key => nil,
                                           :issue_number => nil },
                          :order => :id).each do |issue|
                    issue_number = project_key.reserve_issue_number!
                    issue.update_attributes(:project_key => issue_key, :issue_number => issue_number)
                end
            end
        end

    end

end