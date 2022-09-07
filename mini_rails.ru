require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'

  git_source(:github) { "https://github.com/#{_1}.git" }

  gem 'rails'
  gem 'sqlite3'
  gem 'puma'
  gem 'debug'
end

require 'rails/all'

class MiniRails < Rails::Application
  config.root = __dir__
  config.eager_load = false
  config.consider_all_requests_local = true
  config.secret_key_base = 'secret'
  config.active_storage.service_configurations = {
    local: { service: 'Disk', root: './storage' }
  }

  routes.append do
    root to: 'home#index'
    resources :articles
  end
end

ActiveRecord.legacy_connection_handling = false

ENV['DATABASE_URL'] = 'sqlite3:development.sqlite3'
ActiveRecord::Base.class_eval do
  establish_connection(ENV['DATABASE_URL'])
  self.logger = Logger.new(STDOUT)
end

ActiveRecord::Schema.define do
  create_table :articles, force: true do |t|
    t.column :title, :string, limit: 80, null: false
    t.column :body,  :string, limit: 10_000, null: false
    t.belongs_to :author, null: false
    t.belongs_to :reviewer, null: true
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.column :first_name, :string, null: false
    t.column :last_name, :string, null: false
    t.column :email, :string, null: false
    t.timestamps
  end

  add_foreign_key :articles, :users, column: :author_id
  add_foreign_key :articles, :users, column: :reviewer_id
end

ApplicationRecord = Class.new(ActiveRecord::Base)

class User < ActiveRecord::Base
  has_many :authored_articles, class_name: 'Article'
  has_many :reviewed_articles, class_name: 'Article'

  def full_name
    [first_name, last_name].join(' ')
  end
end

class Article < ActiveRecord::Base
  belongs_to :author, class_name: 'User'
  belongs_to :reviewer, class_name: 'User'
end

ApplicationController = Class.new(ActionController::Base)

class HomeController < ActionController::Base
  include Rails.application.routes.url_helpers

  def index
    @articles = Article.preload(:author, :reviewer)
    
    render inline: VIEW
  end
end

VIEW = <<~ERB
  <h1>Article List</h1>
  <ul>
    <% @articles.each do |article| %>
      <li>
        <strong>
          <a href="<%= article_path(article) %>">
            <%= article.title %>
          </a>
        </strong>
        authored by
        <a href="mailto:<%= article.author.email %>">
          <%= article.author.full_name %>
        </a>
        <% if article.reviewer %>
          reviewed by
          <a href="mailto:<%= article.reviewer.email %>">
            <%= article.reviewer.full_name %>
          </a>
        <% end %>
      </li>
    <% end %>
  </ul>
ERB

begin
  User.insert_all([
    { first_name: 'Joseph', last_name: 'Climber', email: 'joseph.climber@example.com' },
    { first_name: 'Mary',   last_name: 'Climber', email: 'mary.climber@example.com' },
    { first_name: 'John',   last_name: 'Doe',     email: 'john.doe@example.com' },
    { first_name: 'Jane',   last_name: 'Doe',     email: 'jane.doe@example.com' }
  ])
  joseph_id, mary_id, john_id, jane_id = User.pluck(:id)

  Article.insert_all([
    { title: 'A story of overcoming', body: 'Once upon a time...', author_id: joseph_id, reviewer_id: jane_id },
    { title: 'The mother of Jesus', body: 'In the beginning God created...', author_id: mary_id, reviewer_id: john_id },
    { title: 'No one knows', body: 'We get some rules to follow...', author_id: john_id, reviewer_id: mary_id },
    { title: 'Jane says', body: 'I am gonna start tomorrow...', author_id: jane_id, reviewer_id: nil  },
  ])
end

MiniRails.initialize!

run MiniRails