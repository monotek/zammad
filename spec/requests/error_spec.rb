require 'rails_helper'

RSpec.describe 'Error handling', type: :request do

  shared_examples 'JSON response format' do
    let(:as) { :json }

    it { expect(response).to have_http_status(http_status) }
    it { expect(json_response).to be_a_kind_of(Hash) }

    it do
      # There is a special case where we mask technical errors and return
      # a random error code that can be easily found in the logs by an
      # administrator. However, this makes it hard to check for the exact error
      # message. Therefore we only check for the substring in this particular case
      if message == 'Please contact your administrator'
        expect(json_response['error']).to include(message)
      else
        expect(json_response['error']).to eq(message)
      end
    end
  end

  shared_examples 'HTML response format' do
    let(:as) { :html }

    it { expect(response).to have_http_status(http_status) }
    it { expect(response.body).to include('<html') }
    it { expect(response.body).to include("<title>#{title}</title>") }
    it { expect(response.body).to include("<h1>#{headline}</h1>") }
    it { expect(response.body).to include(message) }
  end

  context 'error with confidential message is raised' do

    let(:admin_user) { create(:admin_user, groups: Group.all) }
    let!(:ticket) { create(:ticket) }
    let(:invalid_group_id) { 99_999 }
    let(:message) { 'Please contact your administrator' }
    let(:http_status) { :unprocessable_entity }

    before do
      # fake production ENV to enable error hiding
      env = double(
        production?:  true,
        test?:        false,
        development?: false
      )
      allow(::Rails).to receive(:env).and_return(env)

      authenticated_as(admin_user)
      put "/api/v1/tickets/#{ticket.id}?all=true", params: { group_id: invalid_group_id }, as: as
    end

    context 'requesting JSON' do
      include_examples 'JSON response format'
    end

    context 'requesting HTML' do
      let(:title) { '422: Unprocessable Entity' }
      let(:headline) { '422: The change you wanted was rejected.' }

      include_examples 'HTML response format'
    end
  end

  context 'URL route does not exist' do

    before do
      get '/not_existing_url', as: as
    end

    let(:message) { 'No route matches [GET] /not_existing_url' }
    let(:http_status) { :not_found }

    context 'requesting JSON' do
      include_examples 'JSON response format'
    end

    context 'requesting HTML' do
      let(:title) { '404: Not Found' }
      let(:headline) { '404: Requested resource was not found' }

      include_examples 'HTML response format'
    end
  end

  context 'request is not authenticated' do

    before do
      get '/api/v1/organizations', as: as
    end

    let(:message) { 'authentication failed' }
    let(:http_status) { :unauthorized }

    context 'requesting JSON' do
      include_examples 'JSON response format'
    end

    context 'requesting HTML' do
      let(:title) { '401: Unauthorized' }
      let(:headline) { '401: Unauthorized' }

      include_examples 'HTML response format'
    end
  end

  context 'exception is raised' do

    before do
      get '/tests/raised_exception', params: { exception: exception.name, message: message }, as: as
    end

    shared_examples 'handles exception' do |exception, http_status, title, headline|

      context "#{exception} is raised" do
        let(:exception) { exception }
        let(:http_status) { http_status }
        let(:message) { 'some error message' }

        context 'requesting JSON' do
          include_examples 'JSON response format'
        end

        context 'requesting HTML' do
          let(:title) { title }
          let(:headline) { headline }

          include_examples 'HTML response format'
        end
      end
    end

    include_examples 'handles exception', ActiveRecord::RecordNotFound, :not_found, '404: Not Found', '404: Requested resource was not found'
    include_examples 'handles exception', Exceptions::NotAuthorized, :unauthorized, '401: Unauthorized', '401: Unauthorized'
    include_examples 'handles exception', Exceptions::UnprocessableEntity, :unprocessable_entity, '422: Unprocessable Entity', '422: The change you wanted was rejected.'
    include_examples 'handles exception', ArgumentError, :unprocessable_entity, '422: Unprocessable Entity', '422: The change you wanted was rejected.'
    include_examples 'handles exception', StandardError, :internal_server_error, '500: Something went wrong', "500: We're sorry, but something went wrong."
  end
end
