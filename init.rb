require 'redmine'

require_dependency 'issue_id_hook'

Rails.logger.info 'Starting ISSUE-id Plugin for Redmine'

Query.add_available_column(QueryColumn.new(:legacy_id,
                                           :sortable => "#{Issue.table_name}.id",
                                           :caption => :label_legacy_id))
Query.add_available_column(QueryColumn.new(:issue_id, # FIXME Check latest Redmine & do we really need it? + IssueQuery?
                                           :sortable => [ "#{Issue.table_name}.project_key", "#{Issue.table_name}.issue_number", "#{Issue.table_name}.id" ],
                                           :caption => :label_id)) if Redmine::VERSION::MAJOR > 1

Rails.configuration.to_prepare do
    unless ApplicationHelper.included_modules.include?(IssueApplicationHelperPatch)
        ApplicationHelper.send(:include, IssueApplicationHelperPatch)
    end
    unless IssuesController.included_modules.include?(IssueIdsControllerPatch)
        IssuesController.send(:include, IssueIdsControllerPatch)
    end
    unless IssueRelationsController.included_modules.include?(IssueIdsRelationsControllerPatch)
        IssueRelationsController.send(:include, IssueIdsRelationsControllerPatch)
    end
    unless PreviewsController.included_modules.include?(IssueIdsPreviewsControllerPatch)
        PreviewsController.send(:include, IssueIdsPreviewsControllerPatch)
    end
    unless IssuesHelper.included_modules.include?(IssueIdsHelperPatch)
        IssuesHelper.send(:include, IssueIdsHelperPatch)
    end
    unless QueriesHelper.included_modules.include?(IssueQueriesHelperPatch) # FIXME
        QueriesHelper.send(:include, IssueQueriesHelperPatch)
    end
    unless Project.included_modules.include?(IssueProjectPatch)
        Project.send(:include, IssueProjectPatch)
    end
    unless Issue.included_modules.include?(IssueIdPatch)
        Issue.send(:include, IssueIdPatch)
    end
    unless IssueQuery.included_modules.include?(IssueQueryPatch) # FIXME Query under Redmine 1.4?
        IssueQuery.send(:include, IssueQueryPatch)
    end
    unless Changeset.included_modules.include?(IssueChangesetPatch)
        Changeset.send(:include, IssueChangesetPatch)
    end

    Issue.event_options[:title] = Proc.new do |issue|
        "#{issue.tracker.name} ##{issue.to_param} (#{issue.status}): #{issue.subject}"
    end
    Issue.event_options[:url] = Proc.new do |issue|
        { :controller => 'issues', :action => 'show', :id => issue }
    end

    Journal.event_options[:title] = Proc.new do |journal|
        status = ((new_status = journal.new_status) ? " (#{new_status})" : nil)
        "#{journal.issue.tracker} ##{journal.issue.to_param}#{status}: #{journal.issue.subject}"
    end
    Journal.event_options[:url] = Proc.new do |journal|
        { :controller => 'issues', :action => 'show', :id => journal.issue, :anchor => "change-#{journal.id}" }
    end
end

Redmine::Plugin.register :issue_id do
    name 'ISSUE-id'
    author 'Andriy Lesyuk'
    author_url 'http://www.andriylesyuk.com/'
    description 'Adds support for issue ids in format: CODE-number.'
    url 'http://projects.andriylesyuk.com/projects/issue-id'
    version '0.0.1b'

    settings :default => {
        :issue_key_sharing => false
    }, :partial => 'settings/issue_id'
end
