return unless Rails.env.development?

namespace :db do
  task annotate: :environment do
    puts "Annotating models..."
    system "bundle exec annotaterb models"
  end

  %w[migrate rollback].each do |task|
    Rake::Task["db:#{task}"].enhance do
      Rake::Task["db:annotate"].invoke
    end
  end
end
