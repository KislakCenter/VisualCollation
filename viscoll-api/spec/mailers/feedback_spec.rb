# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackMailer, type: :mailer do
  context 'user submits a feedback' do
    before do
      @user = User.create(name: 'user', email: 'user@mail.com', password: 'user')
    end

    let(:mail) { described_class.sendFeedback('Title of feedback', 'My message', nil, nil, @user.id) }

    it 'sends email' do
      expect(mail.subject).to eq('Title of feedback')
      expect(mail.to).to eq(['test@test.com'])
    end

    it 'renders body' do
      expect(mail.body.raw_source).to include('My message')
      expect(mail.body.raw_source).to include(@user.name)
      expect(mail.body.raw_source).to include(@user.email)
    end
  end
end
